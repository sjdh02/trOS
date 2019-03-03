const builtin = @import("builtin");
const std = @import("std");
const io = @import("../io.zig");
const types = @import("../types.zig");

const mmio = io.mmio;
const uart = io.uart;
const SDError = types.errorTypes.SDError;
const Register = types.regs.Register;

// NOTE(sam): this is pretty much a direct port of https://github.com/bztsrc/raspi3-tutorial/0B_readsector.

const EMMC_ARG1 = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300008 };
const EMMC_ARG2 = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300000 };
const EMMC_BLKSIZECNT = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300004 };
const EMMC_CMDTM = Register { .ReadOnly = mmio.MMIO_BASE + 0x0030000C };
const EMMC_RESP0 = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300010 };
const EMMC_RESP1 = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300014 };
const EMMC_RESP2 = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300018 };
const EMMC_RESP3 = Register { .ReadOnly = mmio.MMIO_BASE + 0x0030001C };
const EMMC_DATA = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300020 };
const EMMC_STATUS = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300024 };
const EMMC_CONTROL0 = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300028 };
const EMMC_CONTROL1 = Register { .ReadOnly = mmio.MMIO_BASE + 0x0030002C };
const EMMC_INTERRUPT = Register { .ReadWrite = mmio.MMIO_BASE + 0x00300030 };
const EMMC_INT_MASK = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300034 };
const EMMC_INT_EN = Register { .ReadOnly = mmio.MMIO_BASE + 0x00300038 };
const EMMC_CONTROL2 = Register { .ReadOnly = mmio.MMIO_BASE + 0x0030003C };
const EMMC_SLOTISR_VER = Register { .ReadOnly = MMIO_BASE + 0x003000FC };

// Control tags
const CMD_NEED_APP = u32(0x80000000);
const CMD_RSPNS_48 = u32(0x00020000);
const CMD_ERRORS_MASK = u32(0xFFF9C004);
const CMD_RCA_MASK = u32(0xFFFF0000);

// Commands
const CMD_GO_IDLE = u32(0x00000000);
const CMD_ALL_SEND_CID = u32(0x02010000);
const CMD_SEND_REL_ADDR = u32(0x03020000);
const CMD_CARD_SELECT = u32(0x07030000);
const CMD_SEND_IF_COND = u32(0x08020000);
const CMD_STOP_TRANS = u32(0x0C030000);
const CMD_READ_SINGLE = u32(0x11220010);
const CMD_READ_MULTI = u32(0x12220032);
const CMD_SET_BLOCKCNT = u32(0x17020000);
const CMD_APP_CMD = u32(0x37000000);
const CMD_SET_BUS_WIDTH = u32((0x06020000 | CMD_NEED_APP));
const CMD_SEND_OP_COND = u32((0x29020000 | CMD_NEED_APP));
const CMD_SEND_SCR = u32((0x33220010 | CMD_NEED_APP));

// Status register
const SR_READ_AVAILABLE = u32(0x00000800);
const SR_DAT_INHIBIT = u32(0x00000002);
const SR_CMD_INHIBIT = u32(0x00000001);
const SR_APP_CMD = u32(0x00000020);

// Interrupt register
const INT_DATA_TIMEOUT = u32(0x00100000);
const INT_CMD_TIMEOUT = u32(0x00010000);
const INT_READ_RDY = u32(0x00000020);
const INT_CMD_DONE = u32(0x00000001);
const INT_ERROR_MASK = u32(0x017E8000);

// Control register
const C0_SPI_MODE_EN = u32(0x00100000);
const C0_HCTL_HS_EN = u32(0x00000004);
const C0_HCTL_DWITDH = u32(0x00000002);
const C1_SRST_DATA = u32(0x04000000);
const C1_SRST_CMD = u32(0x02000000);
const C1_SRST_HC = u32(0x01000000);
const C1_TOUNIT_DIS = u32(0x000f0000);
const C1_TOUNIT_MAX = u32(0x000e0000);
const C1_CLK_GENSEL = u32(0x00000020);
const C1_CLK_EN = u32(0x00000004);
const C1_CLK_STABLE = u32(0x00000002);
const C1_CLK_INTLEN = u32(0x00000001);

// SLOTISR_VER
const HOST_SPEC_NUM = u32(0x00FF0000);
const HOST_SPEC_NUM_SHIFT = u32(16);
const HOST_SPEC_V1 = u32(0);
const HOST_SPEC_V2 = u32(1);
const HOST_SPEC_V3 = u32(2);

// SCR
const SCR_SD_BUS_WIDTH_4 = u32(0x00000400);
const SCR_SUPP_SET_BLKCNT = u32(0x02000000);
const SCR_SUPP_CSS = u32(0x00000001);

// TODO(sam): most of the mmio.wait() calls in the SDHC struct will need to be
// changed to waitMsec() calls, refer to bzt's driver for which need this.

pub const SDHC = struct {
    var cmdCode = u32(0);
    var sdRca = u32(0);
    var sdScr = [2]u8{0, 0};
    var sdHv = u32(0);
    var retCode = u32(0);

    fn getStatus(mask: u32) SDError!void {
        var cnt = isize(1000000);
        while ((mmio.read(EMMC_STATUS).? & mask) == 1 and (mmio.read(EMMC_INTERRUPT).? & INT_ERROR_MASK) != 1) : (cnt -= 1) {
            mmio.wait(1);
        }
        if (cnt <= 0 or (mmio.read(EMMC_INTERRUPT).? & INT_ERROR_MASK) == 1) return SDError.GeneralError else return;
    }

    fn getInterrupt(mask: u32) SDError!bool {
        var cnt = isize(1000000);
        while ((mmio.read(EMMC_INTERRUPT).? & (mask | INT_ERROR_MASK)) != 1) : (cnt -= 1) {
            mmio.wait(1);
        }
        var r = mmio.read(EMMC_INTERRUPT).?;
        if (cnt <= 0 or (r & INT_CMD_TIMEOUT) == 1 or (r & INT_DATA_TIMEOUT) == 1) {
            mmio.write(EMMC_INTERRUPT, r).?;
            return SDError.Timeout;
        } else if ((r & INT_ERROR_MASK) == 1) {
            mmio.write(EMMC_INTERRUPT, r).?;
            return SDError.GeneralError;
        }
        mmio.write(EMMC_INTERRUPT, mask).?;
        return true;
    }

    fn sendCommand(cmd: u32, arg: u32) SDError!void {
        var code = cmd;
        if ((cmd & CMD_NEED_APP) == 1) {
            if (sdRca == 1) {
                sendCommand(CMD_APP_CMD | (if (sdRca == 1) CMD_RSPNS_48 else 0), sdRca) catch |e| {
                    return SDError.GeneralError;
                };
            }
            code &= ~CMD_NEED_APP;
        }
        // make sure the data lines are clear
        getStatus(SR_CMD_INHIBIT) catch |e| {
            uart.write("WARNING: EMMC busy!\n");
            return SDError.Timeout;
        };

        uart.write("Sending EMMC Command: {} {}\n", cmd, arg);
        mmio.write(EMMC_INTERRUPT, mmio.read(EMMC_INTERRUPT).?).?;
        mmio.write(EMMC_ARG1, arg).?;
        mmio.write(EMMC_CMDTM, code).?;

        // NOTE(sam): The following switch is just not right, and needs to be
        // reworked. It may end up needing to be a bunch of if statements,
        // unless I'm thinking of something wrong.

        // switch(code) {
            // CMD_SEND_OP_COND => {
        //         mmio.wait(1000);
        //         if ((getInterrupt(INT_CMD_DONE)) == 1) return SDError.CommandError;
        //     },
        //     CMD_SEND_IF_COND, CMD_APP_CMD => {
        //         mmio.wait(100);
        //         if ((getInterrupt(INT_CMD_DONE)) == 1) return SDError.CommandError;
        //     },
        //     CMD_GO_IDLE, CMD_APP_CMD => return SDError.SDOk,
        //     (CMD_APP_CMD | CMD_RSPNS_48) => return (mmio.read(EMMC_RESP0).? & SR_APP_CMD),
        //     CMD_SEND_OP_COND => return mmio.read(EMMC_RESP0).?,
        //     CMD_SEND_IF_COND => if (mmio.read(EMMC_RESP0).? == arg) return SDError.SDOk else SDError.GeneralError,
        //     CMD_ALL_SEND_CID => {
        //         var r = mmio.read(EMMC_RESP0).?;
        //         r |= mmio.read(EMMC_RESP3).?;
        //         r |= mmio.read(EMMC_RESP2).?;
        //         r |= mmio.read(EMMC_RESP1).?;
        //         retCode =  r;
        //     },
        //     CMD_SEND_REL_ADDR => {
        //         const r = mmio.read(EMMC_RESP0).?;
        //         cmdCode = (((r & 0x1FFF)) | ((r & 0x2000) << 6) | ((r & 0x4000) << 8) | ((r & 0x8000) << 8)) & CMD_ERRORS_MASK;
        //         retCode = (r & CMD_RCA_MASK);
        //     },
        // }
    }

    fn setClock(freq: u32) void {
        // TODO(sam): port this
        unreachable;
    }

    pub fn readBlock(blockAddress: u32, buffer: []u8, blkCount: u32) SDError!u32  {
        if (buffer.len > 128) return SDError.BufferError;
        if (blkCount == 0) return SDError.BlockCount;
        _ = getStatus(SR_DAT_INHIBIT) catch |e| {
            uart.write("WARNING: EMMC busy!\n");
            return SDError.Timeout;
        };
        if ((sdScr[0] & SCR_SUPP_CSS) == 1) {
            if (blkCount > 1 and ((sdScr[0] & SCR_SUPP_SET_BLKCNT) == 1)) {
                // NOTE(sam): in theory this will always return a SDError.CommandError when it fails, but long term it may be worth making sure thats true.
                sendCommand(CMD_SET_BLOCKCNT, blkCount) catch |e| return e;
            }
            mmio.write(EMMC_BLKSIZECNT, ((blkCount << 16) | 512)).?;
            sendCommand((if (blkCount == 1) CMD_READ_SINGLE else CMD_READ_MULTI), blockAddress) catch |e| return e;
        } else {
            mmio.write(EMMC_BLKSIZECNT, ((1 << 16) | 512)).?;
        }
        var curr = u32(0);
        var pos = u32(0);
        while (curr < blkCount) : (curr += 1)  {
            if ((sdScr[0] & SCR_SUPP_CSS) == 0) {
                sendCommand(CMD_READ_SINGLE, ((blockAddress + curr) * 512)) catch |e| return e;
            }
            const r = getInterrupt(INT_READ_RDY) catch |e| {
                uart.write("ERROR: Timeout while waiting for read-ready!\n");
                return e;
            };
            var i = pos + 128;
            while (i < pos) : (i += 1) {
                buffer[i] = @truncate(u8, mmio.read(EMMC_DATA).?);
            }
        }
        if (blkCount > 1 and (sdScr[0] & SCR_SUPP_SET_BLKCNT) == 0 and (sdScr[0] & SCR_SUPP_CSS) == 1) sendCommand(CMD_STOP_TRANS, 0) catch |e| {
            uart.write("ERROR: Failed to send command!\n");
            return e;
        };
        // Return the number of bytes read
        return pos;
    }

    pub fn init() SDError!void {
        // TODO(sam): Port this function
        unreachable;
    }
};
