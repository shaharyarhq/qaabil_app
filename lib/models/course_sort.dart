/// The ways the courses list can be sorted (same options as qaabil.io).
enum CourseSort {
  newest('Newest first'),
  oldest('Oldest first');

  const CourseSort(this.label);

  final String label;
}
