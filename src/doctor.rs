use engine::process::{Manager, Provider, System};
use core::fmt::Write as _;
use engine::error::Result;

use crate::arch::Infra;

impl Infra {

    pub(crate) async fn doctor ( &self ) -> Result<String> {

        let mut out = String::with_capacity(512);

        writeln!(out, "platform={} distro={} arch={} cores={}", System::platform(), System::distro().await, System::arch(), System::cores())?;
        writeln!(out, "host={} user={} root={} pid={}", System::hostname().await.unwrap_or_else(|_failure| "unknown".to_owned()), System::user(), System::is_root().await, System::pid())?;
        writeln!(out, "home={} temp={}", System::home().map(|home| home.display().to_string()).unwrap_or_default(), System::temp().display())?;
        writeln!(out, "memory={}", System::memory().await.map_or_else(|failure| failure.key().to_owned(), |( total, free )| format!("{total}/{free}")))?;
        writeln!(out, "uptime={}", System::uptime().await.map_or_else(|failure| failure.key().to_owned(), |secs| secs.to_string()))?;
        writeln!(out, "manager={}", Manager::detect().await.map_or_else(|failure| failure.key().to_owned(), |manager| manager.to_string()))?;
        writeln!(out, "provider={}", Provider::detect().map_or_else(|failure| failure.key().to_owned(), |provider| provider.to_string()))?;

        self.tool.log().info("doctor").field("platform", System::platform().name()).emit();

        Ok(out)

    }

}
