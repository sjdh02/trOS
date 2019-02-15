// @TODO: Make this more detailed for each type of command error.
pub const SDError = error {
    CommandError,
    Timeout,
    GeneralError,
    Ok,
};

pub const NoError = error{};
