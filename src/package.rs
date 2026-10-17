use engine::process::{Manager, Package, System};
use engine::error::Result;
use engine::log::Outcome;

use crate::arch::{Faults, Infra};

impl Infra {

    pub(crate) async fn package ( &self ) -> Result<String> {

        let action  = self.action()?;
        let package = Package::named(self.name()?);
        let manager = Manager::detect().await?;
        let actor   = System::user();

        let outcome = match action {
            "check"     => return Ok(format!("{}: {}\n", self.name()?, if manager.installed(&package).await { "installed" } else { "absent" })),
            "install"   => manager.install(&package).await,
            "uninstall" => manager.uninstall(&package).await,
            other       => return Err(Faults::UNKNOWN_ACTION.because(format!("{other} is not a package action"))),
        };

        self.tool.log().audit(action).actor(&actor).outcome(if outcome.is_ok() { Outcome::Done } else { Outcome::Failed }).field("package", self.name()?).field("manager", manager.binary()).commit()?;
        outcome?;

        Ok(format!("{action} {}: done via {manager}\n", self.name()?))

    }

}
