// @TODO: Make this more detailed for each type of command error.
pub const SDError = error {
    CommandError,
    Timeout,
    GeneralError,
    ReadError,
    BufferError,
    Ok, // Imply that nothing "failed", but something probably didn't happen that we wanted
};

pub const NoError = error{};
