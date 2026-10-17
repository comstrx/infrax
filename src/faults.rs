use engine::error::{Code, Fault};

use crate::arch::Faults;

impl Faults {

    pub(crate) const NO_NAME: Fault          = Fault::new("no_name", Code::Usage, "a name is required");
    pub(crate) const NO_ACTION: Fault        = Fault::new("no_action", Code::Usage, "an action is required");
    pub(crate) const UNKNOWN_ACTION: Fault   = Fault::new("unknown_action", Code::Usage, "the action is not known");
    pub(crate) const UNKNOWN_PROVIDER: Fault = Fault::new("unknown_provider", Code::Usage, "not a provider: systemd, launchd or windows");

}
