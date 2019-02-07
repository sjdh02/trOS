use crate::mbox::*;

static FONT: &'static [u8; 2080] = include_bytes!("font.psf");

/// Represent a PSF font. This struct is packed to allow the use of
/// `core::ptr::read`.
#[derive(Clone, Copy, Debug)]
#[repr(packed)]
struct PSFFont {
    magic: u32,
    version: u32,
    headersize: u32,
    flags: u32,
    numglyph: u32,
    bytes_per_glyph: u32,
    height: u32,
    width: u32,
    glyphs: u8
}

/// Represent the linear framebuffer of the RPI3. Note that this struct holds a
/// raw pointer, and unsafe code acts on this to write to the framebuffer. See
/// the `impl`'s of this function for more details.
#[derive(Clone, Copy)]
pub struct FrameBufferStream {
    width: u32,
    height: u32,
    pitch: u32,
    x: u32,
    y: u32,
    ptr: *mut u8,
}

impl FrameBufferStream {
    /// Instantiate a new `FrameBufferStream` with a given width and height.
    /// The `ptr` and `pitch` fields are instantiated with filler values.
    pub fn new(width: u32, height: u32) -> FrameBufferStream {
        FrameBufferStream{
            width: width,
            height: height,
            pitch: 0,
            x: 0,
            y: 0,
            ptr: 0xDEADBEEF as *mut u8,
        }
    }

    /// Initialize the linear framebuffer. Performs a mailbox call to set the
    /// resolution, then sets the values for `pitch` and `ptr` of the
    /// `FrameBufferStream` it was called on.
    pub fn init(&mut self, mbox: &mut MailBox) -> Result<bool, &str>{
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
            mbox.mbox[28] &= 0x3FFFFFFF;
            self.pitch = mbox.mbox[33];
            self.ptr = mbox.mbox[28] as *mut u8;
            return Ok(true);
        } else {
            return Err("Failed to initialize framebuffer!");
        }
    }

    /// Write to the framebuffer at a given offset.
    fn write_at_offset(&mut self, offset: u32, d: u8) {
        if offset > 8298239 {
            serial_put!("WARNING: Failed to write at offset {},
                         maximum offset is 8298239!\n", offset);
            return;
        }
        unsafe {
            *self.ptr.offset(offset as isize) = d;
        }
    }

    /// Clear the framebuffer to a given RGB color, in the most
    /// inneficient way possible.
    pub fn clear(&mut self, color: (Option<u8>, Option<u8>, Option<u8>)) {
        for y in 0..self.height {
            for x in 0..self.width * 2 {
                let offset = y * self.pitch + x * 3;
                // @CLEANUP: Could probably make this a little more clean.
                match color {
                    (Some(r), Some(g), Some(b)) => {
                        self.write_at_offset(offset, r);
                        self.write_at_offset(offset + 1, g);
                        self.write_at_offset(offset + 2, b);
                    },
                    (None, Some(g), Some(b)) => {
                        self.write_at_offset(offset, 255);
                        self.write_at_offset(offset + 1, g);
                        self.write_at_offset(offset + 2, b);
                    },
                    (None, None, Some(b)) => {
                        self.write_at_offset(offset, 255);
                        self.write_at_offset(offset + 1, 255);
                        self.write_at_offset(offset + 2, b);
                    },
                    (None, None, None) => {
                        self.write_at_offset(offset, 255);
                        self.write_at_offset(offset + 1, 255);
                        self.write_at_offset(offset + 2, 255);
                    },
                    (Some(r), None, None) => {
                        self.write_at_offset(offset, r);
                        self.write_at_offset(offset + 1, 255);
                        self.write_at_offset(offset + 2, 255);
                    },
                    (None, Some(g), None) => {
                        self.write_at_offset(offset, 255);
                        self.write_at_offset(offset + 1, g);
                        self.write_at_offset(offset + 2, 255);
                    },
                    (Some(r), None, Some(b)) => {
                        self.write_at_offset(offset, r);
                        self.write_at_offset(offset + 1, 255);
                        self.write_at_offset(offset + 2, b);
                    },
                    (Some(r), Some(g), None) => {
                        self.write_at_offset(offset, r);
                        self.write_at_offset(offset + 1, g);
                        self.write_at_offset(offset + 2, 255);
                    },
                }
            }
        }
    }

    pub fn write(&self, data: &str) {
        let font: PSFFont = unsafe { core::ptr::read(FONT.as_ptr() as *const _) };
        let bytes_per_line = (font.width + 7) / 8;
        serial_put!("{:?}\n", font);
    }
}
