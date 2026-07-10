use std::time::{Duration, Instant};

#[cfg(target_os = "windows")]
use std::mem::MaybeUninit;
#[cfg(target_os = "windows")]
use windows_sys::Win32::System::Performance::{QueryPerformanceCounter, QueryPerformanceFrequency};

/// Represents a high-precision timestamp captured with nanosecond resolution.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct PrecisionTimestamp {
    pub nanos: u64,
}

/// A hardware-backed precision clock interface.
/// Provides access to monotonically increasing system timers for drift detection.
pub struct PrecisionClock {
    start_instant: Instant,
    start_nanos: u64,
}

impl PrecisionClock {
    /// Initializes the clock by calibrating the monotonic source.
    pub fn new() -> Self {
        Self {
            start_instant: Instant::now(),
            start_nanos: Self::get_raw_nanos(),
        }
    }

    /// Captures the current system time in nanoseconds since the Unix epoch or process start,
    /// depending on the OS's most stable monotonic source.
    pub fn now(&self) -> PrecisionTimestamp {
        PrecisionTimestamp {
            nanos: self.start_nanos + self.start_instant.elapsed().as_nanos() as u64,
        }
    }

    /// Measures the elapsed time between two timestamps.
    pub fn delta(start: PrecisionTimestamp, end: PrecisionTimestamp) -> Duration {
        Duration::from_nanos(end.nanos.saturating_sub(start.nanos))
    }

    /// Platform-specific implementation for retrieving raw nanoseconds.
    #[cfg(not(target_os = "windows"))]
    fn get_raw_nanos() -> u64 {
        use std::time::SystemTime;
        SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap_or(Duration::ZERO)
            .as_nanos() as u64
    }

    #[cfg(target_os = "windows")]
    fn get_raw_nanos() -> u64 {
        let mut freq = 0i64;
        let mut counter = 0i64;
        unsafe {
            QueryPerformanceFrequency(&mut freq);
            QueryPerformanceCounter(&mut counter);
        }
        if freq == 0 {
            return 0;
        }
        // Convert QPC to nanoseconds: (counter * 1_000_000_000) / frequency
        (counter as u128 * 1_000_000_000 / freq as u128) as u64
    }
}

/// Statistical utilities for calculating drift variance across multiple samples.
pub struct DriftCalculator {
    samples: Vec<u64>,
}

impl DriftCalculator {
    pub fn new() -> Self {
        Self {
            samples: Vec::with_capacity(1000),
        }
    }

    pub fn add_sample(&mut self, timestamp: PrecisionTimestamp) {
        self.samples.push(timestamp.nanos);
    }

    /// Calculates the jitter/drift in nanoseconds between the last two samples
    /// compared to the provided baseline interval.
    pub fn calculate_drift_nanos(&self, expected_interval_ns: u64) -> Option<i64> {
        if self.samples.len() < 2 {
            return None;
        }

        let actual_diff = self.samples[self.samples.len() - 1]
            .saturating_sub(self.samples[self.samples.len() - 2]);
        
        Some(actual_diff as i64 - expected_interval_ns as i64)
    }

    pub fn clear(&mut self) {
        self.samples.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;

    #[test]
    fn test_monotonicity() {
        let clock = PrecisionClock::new();
        let t1 = clock.now();
        thread::sleep(Duration::from_millis(10));
        let t2 = clock.now();
        assert!(t2.nanos > t1.nanos);
    }

    #[test]
    fn test_drift_calculation() {
        let mut calc = DriftCalculator::new();
        let clock = PrecisionClock::new();
        
        calc.add_sample(clock.now());
        thread::sleep(Duration::from_millis(50));
        calc.add_sample(clock.now());

        let drift = calc.calculate_drift_nanos(50_000_000).expect("Should have drift value");
        // We expect drift to be positive but small (due to thread sleep overhead)
        assert!(drift >= 0);
        // Ensure it's reasonably sane (less than 10ms error on a standard OS scheduler)
        assert!(drift < 10_000_000);
    }
}