use engine::thread::Runtime;
use engine::process::Tool;
use engine::error::Result;

use crate::arch::{Faults, Infra};

impl Infra {

    const USAGE: &str = "infra doctor | service <show|install|uninstall|start|stop|restart|status> <name> [--command <path>] [--arg=<x>]... [--cwd <dir>] [--env K=V]... [--provider systemd|launchd|windows] | package <install|uninstall|check> <name>";

    pub(crate) fn run () -> Result<()> {

        let infra = Self { tool: Tool::boot("INFRA", "infra", Self::USAGE)? };

        Runtime::run(infra.dispatch())

    }

    async fn dispatch ( &self ) -> Result<()> {

        if let Some(line) = self.tool.args().version("infra", env!("CARGO_PKG_VERSION")) { return self.tool.answer(&line); }

        let text = match self.tool.command()? {
            "doctor"  => self.doctor().await?,
            "service" => self.service().await?,
            "package" => self.package().await?,
            _         => return Err(self.tool.unknown()),
        };

        self.tool.answer(&text)

    }

    pub(crate) fn name ( &self ) -> Result<&str> {

        self.tool.positional(1, Faults::NO_NAME)

    }

    pub(crate) fn action ( &self ) -> Result<&str> {

        self.tool.positional(0, Faults::NO_ACTION)

    }

}
