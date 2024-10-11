// Copyright 2022 Mandiant, Inc. All Rights Reserved
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software distributed under the License
// is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and limitations under the License.

use csv::Writer;
use macos_unifiedlogs::dsc::SharedCacheStrings;
use macos_unifiedlogs::parser::{build_log, collect_shared_strings, collect_strings, collect_timesync, iter_log, parse_log};
use macos_unifiedlogs::timesync::TimesyncBoot;
use macos_unifiedlogs::unified_log::{LogData, UnifiedLogData};
use macos_unifiedlogs::uuidtext::UUIDText;
use std::fs;
use std::fs::{File, OpenOptions};
use std::path::PathBuf;

use crate::ffi;

// Parse a provided directory path. Currently, expect the path to follow macOS log collect structure.
pub fn parse_log_archive(path: &str, output_path: &str, high_volume_speedup: bool) -> u32 {
    let mut archive_path = PathBuf::from(path);

    // Parse all UUID files which contain strings and other metadata
    let string_results = collect_strings(&archive_path.display().to_string()).unwrap();

    archive_path.push("dsc");
    // Parse UUID cache files which also contain strings and other metadata
    let shared_strings_results =
        collect_shared_strings(&archive_path.display().to_string()).unwrap();
    archive_path.pop();

    archive_path.push("timesync");
    // Parse all timesync files
    let timesync_data = collect_timesync(&archive_path.display().to_string()).unwrap();
    archive_path.pop();

    // Keep UUID, UUID cache, timesync files in memory while we parse all tracev3 files
    // Allows for faster lookups
    let log_count = parse_trace_logarchive(
        &string_results,
        &shared_strings_results,
        &timesync_data,
        path,
        output_path,
        high_volume_speedup,
    );

    println!("\nFinished parsing Unified Log data. Saved results to: output.csv");
    return log_count;
}

// Use the provided strings, shared strings, timesync data to parse the Unified Log data at provided path.
// Currently, expect the path to follow macOS log collect structure.
// If speedup = true, only scan tracev3 files in the Persist & HighVolume folders as they are the only ones containing interesting cellular logs.
fn parse_trace_logarchive(
    string_results: &[UUIDText],
    shared_strings_results: &[SharedCacheStrings],
    timesync_data: &[TimesyncBoot],
    path: &str,
    output_path: &str,
    speedup: bool,
) -> u32 {
    // Create and open the CSV file, so we don't have to open it everytime we write an entry
    let csv_file = OpenOptions::new()
        .append(true)
        .create(true)
        .open(output_path).unwrap();
    // Open the CSV writer
    let mut csv_writer = csv::Writer::from_writer(csv_file);
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

    let mut archive_path = PathBuf::from(path);
    archive_path.push("Persist");
    parse_trace_directory(
        &archive_path,
        string_results, shared_strings_results, timesync_data,
        &mut oversize_strings, &mut missing_data, &mut log_count, &mut csv_writer
    );
    archive_path.pop();

    if !speedup {
        archive_path.push("Special");
        parse_trace_directory(
            &archive_path,
            string_results, shared_strings_results, timesync_data,
            &mut oversize_strings, &mut missing_data, &mut log_count, &mut csv_writer
        );
        archive_path.pop();
    }

    if !speedup {
        archive_path.push("Signpost");
        parse_trace_directory(
            &archive_path,
            string_results, shared_strings_results, timesync_data,
            &mut oversize_strings, &mut missing_data, &mut log_count, &mut csv_writer
        );
        archive_path.pop();
    }

    archive_path.push("HighVolume");
    parse_trace_directory(
        &archive_path,
        string_results, shared_strings_results, timesync_data,
        &mut oversize_strings, &mut missing_data, &mut log_count, &mut csv_writer
    );
    archive_path.pop();

    // We only have LiveData if 'log collect' was used
    if !speedup {
        archive_path.push("logdata.LiveData.tracev3");
        parse_trace_file(
            &archive_path,
            string_results, shared_strings_results, timesync_data,
            &mut oversize_strings, &mut missing_data, &mut log_count, &mut csv_writer
        );
        archive_path.pop();
    }

    // Since we have all oversize entries now,
    // we go through any log entries that we weren't able to build before.
    for mut leftover_data in missing_data {
        // Add all of our previous oversize data to logs for lookups
        leftover_data
            .oversize
            .append(&mut oversize_strings.oversize.to_owned());

        // If we fail to find any missing data its probably due to the logs rolling.
        // Ex: tracev3A rolls, tracev3B references Oversize entry in tracev3A will trigger missing data since tracev3A is gone.
        let (results, _) = build_log(
            &leftover_data,
            string_results,
            shared_strings_results,
            timesync_data,
            false,
        );
        log_count += results.len();

        for result in results {
            if filter_cellular(&result) {
                output_log(&result, &mut csv_writer).unwrap();
            }
        }
    }
    println!("Parsed {} log entries", log_count);

    u32::try_from(log_count).unwrap_or(0)
}

fn parse_trace_directory(
    path: &PathBuf,

    string_results: &[UUIDText],
    shared_strings_results: &[SharedCacheStrings],
    timesync_data: &[TimesyncBoot],

    oversize_strings: &mut UnifiedLogData,
    missing_data: &mut Vec<UnifiedLogData>,
    log_count: &mut usize,
    csv_writer: &mut Writer<File>,
) {
    if !path.exists() {
        println!("Skipping directory {} as it does not exist", path.display());
        return
    }

    // Loop through all tracev3 files in the directory
    let paths = fs::read_dir(&path).unwrap();
    for log_path in paths {
        parse_trace_file(
            &log_path.unwrap().path(),
            string_results, shared_strings_results, timesync_data,
            oversize_strings, missing_data, log_count, csv_writer
        )
    }
}

fn parse_trace_file(
    path: &PathBuf,

    string_results: &[UUIDText],
    shared_strings_results: &[SharedCacheStrings],
    timesync_data: &[TimesyncBoot],

    oversize_strings: &mut UnifiedLogData,
    missing_data: &mut Vec<UnifiedLogData>,
    log_count: &mut usize,
    csv_writer: &mut Writer<File>,
) {
    let full_path = path.display().to_string();

    // Check if file exists and if yes, parse the log data
    let mut log_data = if path.exists() {
        parse_log(&full_path).unwrap()
    } else {
        println!("File {} no longer on disk", full_path);
        return
    };

    println!("Parsing: {}", full_path);
    ffi::swift_parse_trace_file(full_path.as_str(), u32::try_from(*log_count).unwrap_or(0));

    // Append our old Oversize entries in case these logs point to other Oversize entries the previous tracev3 files
    log_data.oversize.append(&mut oversize_strings.oversize);

    // Get all constructed logs and any log data that failed to get constructed (exclude_missing = true)
    let Ok(log_iterator) = iter_log(
        &log_data,
        string_results,
        shared_strings_results,
        timesync_data,
        true,
    ) else {
        println!("Can't open log iterator for file {}", full_path);
        return
    };

    // Need to keep track of any log entries that fail to find Oversize strings
    // as sometimes the strings may be in other log files that have not been parsed yet.
    // TODO: Are we doing double the work here?
    let mut missing_data_file = UnifiedLogData {
        header: Vec::new(),
        catalog_data: Vec::new(),
        oversize: Vec::new(),
    };

    // Iteratively scan the log data
    for (log_data, mut missing_unified_log) in log_iterator {
        for log_entry in log_data {
            if filter_cellular(&log_entry) {
                output_log(&log_entry, csv_writer).unwrap();
                *log_count = *log_count + 1
            }
        }
        missing_data_file
            .header
            .append(&mut missing_unified_log.header);
        missing_data_file
            .catalog_data
            .append(&mut missing_unified_log.catalog_data);
        missing_data_file
            .oversize
            .append(&mut missing_unified_log.oversize);
        // TODO: What to do about oversize strings?
    }

    // Track Oversize entries
    oversize_strings.oversize = log_data.oversize;

    // Track missing logs
    missing_data.push(missing_data_file);
}

fn filter_cellular(log_data: &LogData) -> bool {
    // Pre-scan the log entries written to the CSV file, so that the file is smaller and Swift can parse it faster
    const PROCESSES: [&str; 1] = [
        "/System/Library/Frameworks/CoreTelephony.framework/Support/CommCenter",
        // "/usr/sbin/WirelessRadioManagerd"
    ];
    const SUBSYSTEMS: [&str; 2] = [
        "com.apple.telephony.bb",
        "com.apple.CommCenter"
    ];
    const CONTENTS: [&str; 2] = [
        "kCTCellMonitorCellRadioAccessTechnology",
        "Bin="
    ];

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
pub fn output_header(writer: &mut csv::Writer<fs::File>) -> csv::Result<()> {
    writer.write_record(&[
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
fn output_log(data: &LogData, writer: &mut csv::Writer<fs::File>) -> csv::Result<()> {
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