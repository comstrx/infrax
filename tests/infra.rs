//! Scenario: the real `infra` binary says hello, answers `--version`, and refuses what it does not know as usage.

#[cfg(test)]
mod tests {

    use std::io::{Error as IoError, Result as IoResult};
    use engine::process::Cargo;
    use std::process::Output;
    use std::path::Path;

    fn run ( args: &[&str], env: &[( &str, &str )] ) -> IoResult<Output> {

        let mut command = Cargo::command(Path::new(env!("CARGO_MANIFEST_DIR")), "infra", false, "INFRA_").map_err(|failure| IoError::other(failure.to_string()))?;

        command.args(args).envs(env.iter().copied()).output()

    }

    fn text ( bytes: &[u8] ) -> String {

        String::from_utf8_lossy(bytes).into_owned()

    }

    #[test]
    fn hello_says_hello_and_logs_it () {

        let plain  = run(&["hello"], &[]).ok();
        let logged = run(&["hello"], &[( "INFRA_LOG", "info" )]).ok();

        assert_eq!(plain.as_ref().and_then(|output| output.status.code()), Some(0));
        assert_eq!(plain.map(|output| text(&output.stdout)), Some("hello world\n".to_owned()));
        assert!(logged.is_some_and(|output| output.status.code() == Some(0) && text(&output.stdout) == "hello world\n" && text(&output.stderr).contains(" infra: hello")));

    }

    #[test]
    fn the_version_is_answered_before_anything_else () {

        let output = run(&["--version"], &[]).ok();

        assert_eq!(output.as_ref().and_then(|output| output.status.code()), Some(0));
        assert!(output.is_some_and(|output| text(&output.stdout).trim() == format!("infra {}", env!("CARGO_PKG_VERSION"))));

    }

    #[test]
    fn no_command_and_an_unknown_command_are_usage () {

        let none = run(&[], &[]).ok();
        let odd  = run(&["dance"], &[]).ok();

        assert!(none.is_some_and(|output| output.status.code() == Some(64) && text(&output.stderr).contains("in: infra hello")));
        assert!(odd.is_some_and(|output| output.status.code() == Some(64) && text(&output.stderr).contains("does not know the command dance")));

    }

}
