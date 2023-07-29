mod csv_parser;

#[swift_bridge::bridge]
mod ffi {
    extern "Rust" {
        type RustApp;

        #[swift_bridge(init)]
        fn new() -> RustApp;

        fn generate_html(&self) -> &str;

        fn parse_system_log(&self, input: &str, output: &str) -> &str;
    }
}

pub struct RustApp {}

impl RustApp {
    fn new() -> Self {
        RustApp {}
    }

    fn generate_html(&self) -> &str {
        return "Hey";
    }

    fn parse_system_log(&self, input: &str, output: &str) -> &str {
        csv_parser::output_header(output).unwrap();
        csv_parser::parse_log_archive(input, output);
        // TODO: Return error or so or the number things parsed
        return "Hoo";
    }
}
