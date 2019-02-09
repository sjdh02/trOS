use trOS_mbox::mbox::*;
use trOS_phys::mmio::write;

// @TODO: Remove this when SD card support lands.
static FONT: &'static [u8; 2080] = include_bytes!("font.psf");

/// Represent a PSF font. This struct is packed to allow the use of
/// `core::ptr::read`.
#[repr(C, packed)]
struct PSFFont {
    magic: u32,
    version: u32,
    headersize: u32,
    flags: u32,
    numglyph: u32,
    bytes_per_glyph: u32,
    height: u32,
    width: u32,
}

/// Represent the linear framebuffer of the RPI3. Note that this struct holds a
/// raw pointer, and unsafe code acts on this to write to the framebuffer. See
/// the `impl`'s of this function for more details.
pub struct FrameBufferStream {
    width: u32,
    height: u32,
    pitch: u32,
    x: u32,
    y: u32,
    ptr: *mut u8,
}

impl Default for FrameBufferStream {
    fn default() -> Self {
        FrameBufferStream{
            width: 1920,
            height: 1080,
            pitch: 0,
            x: 0,
            y: 0,
            ptr: 0xDEAD_BEEF as *mut u8,
        }
    }
}

impl FrameBufferStream {
    /// Instantiate a new `FrameBufferStream` with a given width and height.
    /// The `ptr` and `pitch` fields are instantiated with filler values.
    pub fn new(width: u32, height: u32) -> Self {
        FrameBufferStream{
            width: width,
            height: height,
            pitch: 0,
            x: 0,
            y: 0,
            ptr: 0xDEAD_BEEF as *mut u8,
        }
    }

    /// Initialize the linear framebuffer. Performs a mailbox call to set the
    /// resolution, then sets the values for `pitch` and `ptr` of the
    /// `FrameBufferStream` it was called on.
    pub fn init(&mut self, mbox: &mut MailBox) -> Result<(), &str>{
        // Clear the mailbox and setup the new call
        mbox.clear();
        mbox.mbox[0] = 35 * 4;
        mbox.mbox[1] = MBOX_REQUEST;
        mbox.mbox[2] = 0x48003; //set phy wh
        mbox.mbox[3] = 8;
        mbox.mbox[4] = 8;
        mbox.mbox[5] = self.width;
        mbox.mbox[6] = self.height;

        mbox.mbox[7] = 0x48004; //set virt wh
        mbox.mbox[8] = 8;
        mbox.mbox[9] = 8;
        mbox.mbox[10] = self.width;
        mbox.mbox[11] = self.height;

        mbox.mbox[12] = 0x48009; //set virt offset
        mbox.mbox[13] = 8;
        mbox.mbox[14] = 8;
        mbox.mbox[15] = 0;
        mbox.mbox[16] = 0;

        mbox.mbox[17] = 0x48005; //set depth
        mbox.mbox[18] = 4;
        mbox.mbox[19] = 4;
        mbox.mbox[20] = 32;

        mbox.mbox[21] = 0x48006; //set pixel order
        mbox.mbox[22] = 4;
        mbox.mbox[23] = 4;
        mbox.mbox[24] = 1;

        mbox.mbox[25] = 0x40001; //get framebuffer, gets alignment on request
        mbox.mbox[26] = 8;
        mbox.mbox[27] = 8;
        mbox.mbox[28] = 4096;
        mbox.mbox[29] = 0;

        mbox.mbox[30] = 0x40008; //get pitch
        mbox.mbox[31] = 4;
        mbox.mbox[32] = 4;
        mbox.mbox[33] = 0;

        mbox.mbox[34] = MBOX_TAG_LAST;

        if mbox.call(MBOX_CH_PROP) && mbox.mbox[20] == 32 && mbox.mbox[28] != 0 {
            mbox.mbox[28] &= 0x3FFF_FFFF;
            self.pitch = mbox.mbox[33];
            self.ptr = mbox.mbox[28] as *mut u8;
            Ok(())
        } else {
            Err("Failed to initialize framebuffer!")
        }
    }

    /// Write to the framebuffer at a given offset.
    fn write_at_offset(&mut self, offset: u32, d: u8) -> Result<(), &str> {
        if offset > 8_298_239 {
            return Err("WARNING: failed to write to offset, maximum offset is 8298239!");
        }
        unsafe {
            write((self.ptr.offset(offset as isize)) as *mut u32, d.into());
        }
        Ok(())
    }

    /// Clear the framebuffer to a given RGB color, in the most
    /// inneficient way possible.
    pub fn clear(&mut self, r: u8, g: u8, b: u8) {
        for y in 0..self.height {
            for x in 0..self.width * 2 {
                let offset = y * self.pitch + x * 3;
                self.write_at_offset(offset, r).unwrap();
                self.write_at_offset(offset + 1, g).unwrap();
                self.write_at_offset(offset + 2, b).unwrap();
            }
        }
    }

    pub fn write(&mut self, data: &str) {
        let font = unsafe { core::ptr::read(FONT.as_ptr() as *const PSFFont) };
        for c in data.chars() {
            let bytes_per_line = (font.width + 7) / 8;
            //let mut ptr = unsafe {(FONT.as_ptr()).offset(font.headersize as isize).offset(('A' as u32 * font.bytes_per_glyph) as isize)};
            let mut ptr = unsafe {(FONT.as_ptr()).offset(font.headersize as isize).offset((c as u32 * font.bytes_per_glyph) as isize)};
            let mut offset = (self.y * font.height * self.pitch) + (self.x * (font.width + 1) * 4);
            if c == '\r' {
                self.x = 0;
            } else if c == '\n' {
                self.x = 0;
                self.y += 1;
            } else {
                for _ in 0..font.height {
                    let mut line = offset;
                    let mut mask = 1 << (font.width - 1);
                    for _ in 0..font.width {
                        let color = unsafe { if *ptr & mask == 0 { 0 } else { 255 }};
                        self.write_at_offset(line, color).unwrap();
                        self.write_at_offset(line + 1, color).unwrap();
                        self.write_at_offset(line + 2, color).unwrap();
                        mask >>= 1;
                        line += 4;
                    }
                    ptr = unsafe {ptr.offset(bytes_per_line as isize)};
                    offset += self.pitch;
                }
                self.x += 1;
            }
        }
    }
}
