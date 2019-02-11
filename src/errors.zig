pub const FrameBufferError = error {
    InitializationError,
};

pub const CommandError = error {
    ParseError,
};

pub const RegisterError = error {
    BadType,
};
