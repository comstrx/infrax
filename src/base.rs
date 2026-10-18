use engine::process::Tool;
use engine::error::Result;

use crate::arch::Infra;

impl Infra {

    const USAGE: &str = "infra hello";

    const GREETING: &str = "hello world\n";

    pub(crate) fn run () -> Result<()> {

        let infra = Self { tool: Tool::boot("INFRA", "infra", Self::USAGE)? };

        infra.dispatch()

    }

    fn dispatch ( &self ) -> Result<()> {

        if let Some(line) = self.tool.args().version("infra", env!("CARGO_PKG_VERSION")) { return self.tool.answer(&line); }

        match self.tool.command()? {
            "hello" => self.hello(),
            _       => Err(self.tool.unknown()),
        }

    }

    fn hello ( &self ) -> Result<()> {

        self.tool.log().info("hello").emit();
        self.tool.answer(Self::GREETING)

    }

}
