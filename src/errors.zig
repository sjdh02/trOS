pub const FrameBufferError = error {
    InitializationError,
    GlyphNotFound,
};

pub const CommandError = error {
    ParseError,
};
