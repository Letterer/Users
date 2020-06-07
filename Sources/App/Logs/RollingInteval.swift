/// Specifies the frequency at which the log file should roll.
public enum RollingInteval: String {
    /// The log file will never roll; no time period information will be appended to the log file name.
    case infinite = ""

    /// Roll every year. Filenames will have a four-digit year appended in the pattern `yyyy`.
    case year = "yyyy"

    /// Roll every calendar month. Filenames will have `yyyyMM` appended.
    case month = "yyyyMM"

    /// Roll every day. Filenames will have `yyyyMMdd` appended.
    case day = "yyyyMMdd"

    /// Roll every hour. Filenames will have `yyyyMMddHH` appended.
    case hour = "yyyyMMddHH"

    /// Roll every minute. Filenames will have `yyyyMMddHHmm` appended.
    case minute = "yyyyMMddHHmm"
}
