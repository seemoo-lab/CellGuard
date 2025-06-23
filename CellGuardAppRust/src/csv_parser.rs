use crate::ffi;
use csv::Writer;
use macos_unifiedlogs::filesystem::LogarchiveProvider;
use macos_unifiedlogs::iterator::UnifiedLogIterator;
use macos_unifiedlogs::parser::{build_log, collect_timesync};
use macos_unifiedlogs::timesync::TimesyncBoot;
use macos_unifiedlogs::traits::FileProvider;
use macos_unifiedlogs::unified_log::{LogData, UnifiedLogData};
use std::collections::HashMap;
use std::fs::{File, OpenOptions};
use std::io::Read;
use std::path::Path;

// Parse a provided directory path. Currently, expect the path to follow macOS log collect structure.
pub fn parse_log_archive(path: &Path, output_path: &Path, high_volume_speedup: bool) -> u32 {
    let mut provider = LogarchiveProvider::new(path);

    // Parse all timesync files
    let timesync_data = collect_timesync(&provider).unwrap();

    // Keep UUID, UUID cache, timesync files in memory while we parse all tracev3 files
    // Allows for faster lookups
    let log_count = parse_trace_logarchive(
        &timesync_data,
        &mut provider,
        output_path,
        high_volume_speedup,
    );

    // TODO: We could use the oslog crate for logging: https://lib.rs/crates/oslog
    println!("\nFinished parsing Unified Log data. Saved results to: output.csv");
    log_count
}

// Use the provided strings, shared strings, timesync data to parse the Unified Log data at provided path.
// Currently, expect the path to follow macOS log collect structure.
// If speedup = true, only scan tracev3 files in the Persist & HighVolume folders as they are the only ones containing interesting cellular logs.
fn parse_trace_logarchive(
    timesync_data: &HashMap<String, TimesyncBoot>,
    provider: &mut dyn FileProvider,
    output_path: &Path,
    speedup: bool,
) -> u32 {
    // Create and open the CSV file, so we don't have to open it everytime we write an entry
    let csv_file = OpenOptions::new()
        .append(true)
        .create(true)
        .open(output_path)
        .unwrap();
    // Open the CSV writer
    let mut csv_writer = Writer::from_writer(csv_file);
    // Write the CSV header
    output_header(&mut csv_writer).unwrap();

    // We need to persist the Oversize log entries (they contain large strings that don't fit in normal log entries)
    // Some log entries have Oversize strings located in different tracev3 files.
    // This is very rare. Seen in ~20 log entries out of ~700,000. Seen in ~700 out of ~18 million
    let mut oversize_strings = UnifiedLogData {
        header: Vec::new(),
        catalog_data: Vec::new(),
        oversize: Vec::new(),
    };

    // Exclude missing data from returned output. Keep separate until we parse all oversize entries.
    // Then at end, go through all missing data and check all parsed oversize entries again
    let mut missing_data: Vec<UnifiedLogData> = Vec::new();

    // Counting the number of read log entries
    let mut log_count: usize = 0;

    for mut source in provider.tracev3_files() {
        // Check if we should skip the file when the speedup is enabled
        let path = source.source_path();
        if speedup && path.contains("Special")
            || path.contains("Signpost")
            || path.ends_with("logdata.LiveData.tracev3")
        {
            continue;
        }

        println!("Parsing: {}", path);
        ffi::swift_parse_trace_file(path, u32::try_from(log_count).unwrap_or(0));

        log_count += iterate_chunks(
            source.reader(),
            provider,
            timesync_data,
            &mut missing_data,
            &mut oversize_strings,
            &mut csv_writer,
        );
    }

    println!("Oversize cache size: {}", oversize_strings.oversize.len());
    println!("Logs with missing Oversize strings: {}", missing_data.len());
    println!("Checking Oversize cache one more time...");

    // Since we have all oversize entries now,
    // we go through any log entries that we weren't able to build before.
    for mut leftover_data in missing_data {
        // Add all of our previous oversize data to logs for lookups
        leftover_data.oversize = oversize_strings.oversize.clone();

        // If we fail to find any missing data its probably due to the logs rolling.
        // Ex: tracev3A rolls, tracev3B references Oversize entry in tracev3A will trigger missing data since tracev3A is gone.
        let (results, _) = build_log(&leftover_data, provider, timesync_data, false);

        for result in results {
            if filter_cellular(&result) {
                output_log(&result, &mut csv_writer).unwrap();
                log_count += 1
            }
        }
    }
    println!("Parsed {} log entries", log_count);

    u32::try_from(log_count).unwrap_or(0)
}

fn iterate_chunks(
    mut reader: impl Read,

    provider: &mut dyn FileProvider,
    timesync_data: &HashMap<String, TimesyncBoot>,

    missing: &mut Vec<UnifiedLogData>,
    oversize_strings: &mut UnifiedLogData,
    csv_writer: &mut Writer<File>,
) -> usize {
    let mut buf = Vec::new();

    if let Err(e) = reader.read_to_end(&mut buf) {
        println!("Failed to read tracev3 file: {:?}", e);
        return 0;
    }

    let log_iterator = UnifiedLogIterator {
        data: buf,
        header: Vec::new(),
    };

    // Exclude missing data from returned output. Keep separate until we parse all oversize entries.
    // Then after parsing all logs, go through all missing data and check all parsed oversize entries again
    let exclude_missing = true;

    let mut count = 0;
    for mut chunk in log_iterator {
        chunk.oversize.append(&mut oversize_strings.oversize);
        let (results, missing_logs) = build_log(&chunk, provider, timesync_data, exclude_missing);

        for log_entry in results {
            if filter_cellular(&log_entry) {
                output_log(&log_entry, csv_writer).unwrap();
                count += 1;
            }
        }

        // Track oversize entries
        oversize_strings.oversize = chunk.oversize;

        if missing_logs.catalog_data.is_empty()
            && missing_logs.header.is_empty()
            && missing_logs.oversize.is_empty()
        {
            continue;
        }
        // Track possible missing log data due to oversize strings being in another file
        missing.push(missing_logs);
    }

    count
}

fn filter_cellular(log_data: &LogData) -> bool {
    // Pre-scan the log entries written to the CSV file, so that the file is smaller and Swift can parse it faster
    const PROCESSES: [&str; 1] = [
        "/System/Library/Frameworks/CoreTelephony.framework/Support/CommCenter",
        // "/usr/sbin/WirelessRadioManagerd"
    ];
    // Remove reference to "com.apple.CommCenter" once we only use the packet-based cell extraction.
    const SUBSYSTEMS: [&str; 2] = ["com.apple.telephony.bb", "com.apple.CommCenter"];
    // Remove reference to CellInfo once we only use
    // the packet-based cell extraction.
    const CONTENTS: [&str; 2] = ["CellInfo", "Bin="];

    if !PROCESSES.contains(&log_data.process.as_str()) {
        return false;
    }

    if !SUBSYSTEMS.contains(&log_data.subsystem.as_str()) {
        return false;
    }

    for content_query in &CONTENTS {
        if log_data.message.contains(content_query) {
            return true;
        }
    }

    false
}

// Create CSV header row
pub fn output_header(writer: &mut Writer<File>) -> csv::Result<()> {
    writer.write_record([
        "Timestamp",
        // "Event Type",
        // "Log Type",
        "Subsystem",
        // "Thread ID",
        // "PID",
        // "EUID",
        "Library",
        // "Library UUID",
        // "Activity ID",
        "Category",
        // "Process",
        // "Process UUID",
        "Message",
        // "Raw Message",
        // "Boot UUID",
        // "System Timezone Name",
    ])
}

// Append a log entry to the CSV file
fn output_log(data: &LogData, writer: &mut Writer<File>) -> csv::Result<()> {
    writer.write_record(&[
        data.time.to_string(),
        // data.event_type.to_owned(),
        // data.log_type.to_owned(),
        data.subsystem.to_owned(),
        // data.thread_id.to_string(),
        // data.pid.to_string(),
        // data.euid.to_string(),
        data.library.to_owned(),
        // data.library_uuid.to_owned(),
        // data.activity_id.to_string(),
        data.category.to_owned(),
        // data.process.to_owned(),
        // data.process_uuid.to_owned(),
        data.message.to_owned(),
        // data.raw_message.to_owned(),
        // data.boot_uuid.to_owned(),
        // data.timezone_name.to_owned(),
    ])
}
