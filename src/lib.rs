extern crate alloc;

mod csv_parser;

#[swift_bridge::bridge]
mod ffi {
    extern "Rust" {
        type RustApp;

        #[swift_bridge(init)]
        fn new() -> RustApp;

        fn parse_system_log(&self, input: &str, output: &str) -> &str;
    }

    extern "Swift" {
        fn swift_parse_trace_file(path: &str, count: u32);
    }
}

pub struct RustApp {}

impl RustApp {
    fn new() -> Self {
        RustApp {}
    }

    fn parse_system_log(&self, input: &str, output: &str) -> &str {
        csv_parser::output_header(output).unwrap();
        csv_parser::parse_log_archive(input, output);
        // TODO: Return error or so or the number things parsed
        return "Hoo";
    }
}
