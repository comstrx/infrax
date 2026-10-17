//! Scenario: the real `infra` binary: doctor, units rendered, a missing service, packages refused without a name, usage.

#[cfg(test)]
mod tests {

    use std::io::{Error as IoError, Result as IoResult};
    use engine::process::Cargo;
    use std::process::Output;
    use std::path::Path;

    fn run ( args: &[&str] ) -> IoResult<Output> {

        let mut command = Cargo::command(Path::new(env!("CARGO_MANIFEST_DIR")), "infra", false, "INFRA_").map_err(|failure| IoError::other(failure.to_string()))?;

        command.args(args).output()

    }

    fn text ( bytes: &[u8] ) -> String {

        String::from_utf8_lossy(bytes).into_owned()

    }

    #[test]
    fn doctor_reports_the_machine () {

        let output = run(&["doctor"]).ok();
        let stdout = output.as_ref().map(|output| text(&output.stdout)).unwrap_or_default();

        assert_eq!(output.and_then(|output| output.status.code()), Some(0));
        assert!(stdout.starts_with("platform=") && stdout.contains(" cores=") && stdout.contains("\nhost=") && stdout.contains("\nmanager=") && stdout.contains("\nprovider="));

    }

    #[test]
    fn a_unit_is_rendered_for_the_named_provider () {

        let output = run(&["service", "show", "iam", "--command", "/opt/iam/bin/iam", "--arg=--serve", "--env", "IAM_LOG=info", "--provider", "systemd"]).ok();
        let stdout = output.as_ref().map(|output| text(&output.stdout)).unwrap_or_default();

        assert_eq!(output.and_then(|output| output.status.code()), Some(0));
        assert!(stdout.starts_with("[Unit]\nDescription=iam\n"));
        assert!(stdout.contains("\nExecStart=/opt/iam/bin/iam --serve\n") && stdout.contains("\nEnvironment=IAM_LOG=info\n"));

        let plist = run(&["service", "show", "iam", "--command", "/opt/iam/bin/iam", "--provider", "launchd"]).ok().map(|output| text(&output.stdout)).unwrap_or_default();

        assert!(plist.starts_with("<?xml") && plist.contains("<string>iam</string>"));

    }

    #[test]
    fn a_missing_service_is_missing_and_bad_input_is_usage () {

        let status = run(&["service", "status", "no-such-service-xyz"]).ok();

        assert!(status.as_ref().is_some_and(|output| output.status.code() == Some(0) && text(&output.stdout).trim() == "missing" || output.status.code() == Some(70)));

        let none  = run(&[]).ok();
        let odd   = run(&["dance"]).ok();
        let short = run(&["service", "show"]).ok();
        let flag  = run(&["service", "show", "iam"]).ok();
        let bad   = run(&["service", "show", "iam", "--command", "/x", "--provider", "sysv"]).ok();
        let pkg   = run(&["package", "frobnicate", "git"]).ok();

        assert_eq!(none.as_ref().and_then(|output| output.status.code()), Some(64));
        assert!(none.is_some_and(|output| text(&output.stderr).contains("in: infra doctor | service")));
        assert_eq!(odd.and_then(|output| output.status.code()), Some(64));
        assert_eq!(short.and_then(|output| output.status.code()), Some(64));
        assert!(flag.is_some_and(|output| output.status.code() == Some(64) && text(&output.stderr).contains("--command is required")));
        assert!(bad.is_some_and(|output| output.status.code() == Some(64) && text(&output.stderr).contains("sysv is not a provider")));
        assert!(pkg.is_some_and(|output| output.status.code() == Some(64) || output.status.code() == Some(70)));

    }

}
