// import '../config/constants.dart';
//
// /// Service status is derived only from date of birth (age ≥ 60 = Retired).
// class ServiceStatusUtils {
//   ServiceStatusUtils._();
//
//   static String fromDateOfBirth(DateTime dateOfBirth) {
//     final age = _ageOn(DateTime.now(), dateOfBirth);
//     return age >= 60 ? ServiceStatus.retired : ServiceStatus.inService;
//   }
//
//   static int ageOn(DateTime onDate, DateTime dateOfBirth) => _ageOn(onDate, dateOfBirth);
//
//   static int _ageOn(DateTime onDate, DateTime dateOfBirth) {
//     var age = onDate.year - dateOfBirth.year;
//     if (onDate.month < dateOfBirth.month ||
//         (onDate.month == dateOfBirth.month && onDate.day < dateOfBirth.day)) {
//       age--;
//     }
//     return age;
//   }
// }
