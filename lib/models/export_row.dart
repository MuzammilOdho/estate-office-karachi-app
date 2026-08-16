/// One row of an exported report — one row per payment, with unit and
/// occupant details repeated on every row. Columns match the office's
/// Excel register layout (22 columns A–V).
///
/// Payment fields (`paymentDate`, `amountRecovered`, `remarks`) are nullable
/// so that allotments with zero payments can still produce a row.
///
/// Date fields (`dateOfOccupation`, `dateOfAllotment`) are nullable so that
/// vacant units (no allotments) can produce a row with blank date columns.
class ExportRow {
  // --- Unit fields ---
  final String type;       // B — Category / Type
  final String houseNo;    // C — House No
  final String block;       // D — Block No.
  final String flatNo;      // E — Flat No
  final String colony;      // F — Colony

  // --- Allottee fields ---
  final String personalNo;  // G — Personal No
  final String allotteeName; // H — FGS Name
  final String designation;  // I — FGS Designation
  final String bs;          // J — BS
  final String department;  // K — Department
  final String cnic;        // L — FGS CNIC

  // --- Allotment date fields (nullable for vacant units) ---
  final DateTime? dateOfOccupation;  // M — Date Of Occupation
  final DateTime? dateOfAllotment;   // N — Allotment Date
  final DateTime? dob;               // O — Date Of Birth
  final DateTime? dateOfRetirement;  // P — Date of Retirement (auto from DOB)

  // --- Manual-entry columns (blank in CSV, filled in Excel) ---
  // Q — Previous Outstanding Balance
  // R — Demand of Current FY

  // --- Payment fields (nullable for allotments with no payments) ---
  final DateTime? paymentDate;       // S — Payment Date
  final double amountRecovered;      // T — Rent Amount Recovered through Challans
  final String remarks;              // V — Remarks

  // --- Manual-entry column ---
  // U — Total Outstanding

  const ExportRow({
    required this.type,
    required this.houseNo,
    required this.block,
    required this.flatNo,
    required this.colony,
    required this.personalNo,
    required this.allotteeName,
    required this.designation,
    required this.bs,
    required this.department,
    required this.cnic,
    this.dateOfOccupation,
    this.dateOfAllotment,
    this.dob,
    this.dateOfRetirement,
    this.paymentDate,
    this.amountRecovered = 0,
    this.remarks = '',
  });
}
