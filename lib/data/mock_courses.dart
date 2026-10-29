import '../models/course.dart';
import '../models/curriculum.dart';

/// Hard-coded courses used until we connect a real backend.
///
/// This is `final` instead of `const` because `DateTime(...)` can't be const.
/// The curricula are short samples, not the full Cambridge syllabuses.
final List<Course> mockCourses = [
  Course(
    title: 'Mathematics (0580)',
    description: 'Algebra, geometry, statistics and more.',
    qualification: Qualification.igcse,
    videos: 18,
    addedOn: DateTime(2026, 10, 16),
    curriculum: const [
      CourseSection(
        title: 'Number',
        chapters: [
          Chapter(
            title: 'Types of number',
            objectives: [
              LearningObjective(
                code: '1.1',
                title: 'Identify natural numbers, integers, primes and factors',
              ),
              LearningObjective(
                code: '1.2',
                title: 'Find the HCF and LCM of two numbers',
                // "HCF, LCM and Product of Prime Factors" by The Math Pad.
                youtubeVideoId: 'eNEgvVJI_zw',
              ),
            ],
          ),
          Chapter(
            title: 'Fractions, decimals and percentages',
            objectives: [
              LearningObjective(
                code: '2.1',
                title: 'Convert between fractions, decimals and percentages',
              ),
            ],
          ),
        ],
      ),
      CourseSection(
        title: 'Algebra and graphs',
        chapters: [
          Chapter(
            title: 'Linear equations',
            objectives: [
              LearningObjective(
                code: '3.1',
                title: 'Solve linear equations in one unknown',
              ),
              LearningObjective(
                code: '3.2',
                title: 'Solve simultaneous linear equations',
              ),
            ],
          ),
          Chapter(
            title: 'Quadratics',
            objectives: [
              LearningObjective(
                code: '4.1',
                title: 'Factorise and solve quadratic equations',
              ),
            ],
          ),
        ],
      ),
      CourseSection(
        title: 'Statistics',
        chapters: [
          Chapter(
            title: 'Averages and range',
            objectives: [
              LearningObjective(
                code: '5.1',
                title: 'Calculate mean, median, mode and range',
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  Course(
    title: 'Physics (0625)',
    description: 'Forces, energy, waves, electricity and magnetism.',
    qualification: Qualification.igcse,
    videos: 11,
    addedOn: DateTime(2026, 9, 28),
    curriculum: const [
      CourseSection(
        title: 'Motion, forces and energy',
        chapters: [
          Chapter(
            title: 'Speed, velocity and acceleration',
            objectives: [
              LearningObjective(
                code: '1.1',
                title: 'Calculate speed from distance and time',
              ),
              LearningObjective(code: '1.2', title: 'Read speed-time graphs'),
            ],
          ),
          Chapter(
            title: 'Energy',
            objectives: [
              LearningObjective(
                code: '2.1',
                title: 'Describe energy stores and transfers',
              ),
            ],
          ),
        ],
      ),
      CourseSection(
        title: 'Electricity and magnetism',
        chapters: [
          Chapter(
            title: 'Circuits',
            objectives: [
              LearningObjective(
                code: '3.1',
                title: 'Use V = IR in series and parallel circuits',
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  Course(
    title: 'Chemistry (0620)',
    description: 'Atoms, bonding, reactions and organic chemistry.',
    qualification: Qualification.igcse,
    videos: 7,
    addedOn: DateTime(2026, 9, 10),
    curriculum: const [
      CourseSection(
        title: 'Atoms and bonding',
        chapters: [
          Chapter(
            title: 'Atomic structure',
            objectives: [
              LearningObjective(
                code: '1.1',
                title: 'Describe protons, neutrons and electrons',
              ),
            ],
          ),
          Chapter(
            title: 'Ionic and covalent bonds',
            objectives: [
              LearningObjective(
                code: '2.1',
                title: 'Explain how ionic bonds form',
              ),
              LearningObjective(
                code: '2.2',
                title: 'Draw dot-and-cross diagrams for covalent molecules',
              ),
            ],
          ),
        ],
      ),
      CourseSection(
        title: 'Organic chemistry',
        chapters: [
          Chapter(
            title: 'Alkanes and alkenes',
            objectives: [
              LearningObjective(
                code: '3.1',
                title: 'Name and draw the first four alkanes',
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  Course(
    title: 'Biology (0610)',
    description: 'Cells, human biology, plants and ecology.',
    qualification: Qualification.igcse,
    videos: 3,
    addedOn: DateTime(2026, 8, 22),
    curriculum: const [
      CourseSection(
        title: 'Cells and organisms',
        chapters: [
          Chapter(
            title: 'Cell structure',
            objectives: [
              LearningObjective(
                code: '1.1',
                title: 'Compare animal and plant cells',
              ),
            ],
          ),
          Chapter(
            title: 'Movement into and out of cells',
            objectives: [
              LearningObjective(
                code: '2.1',
                title: 'Explain diffusion and osmosis',
                // "Diffusion, Osmosis and Active Transport" by IGCSE with Han.
                youtubeVideoId: 'KfBxhErUJMk',
              ),
            ],
          ),
          Chapter(
            title: 'Enzymes',
            objectives: [
              LearningObjective(
                code: '3.1',
                title: 'Describe how temperature and pH affect enzymes',
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  Course(
    title: 'Mathematics (9709)',
    description: 'Pure maths, mechanics and probability & statistics.',
    qualification: Qualification.aLevel,
    videos: 0,
    addedOn: DateTime(2026, 10, 18),
    curriculum: const [
      CourseSection(
        title: 'Pure Mathematics 1',
        chapters: [
          Chapter(
            title: 'Functions',
            objectives: [
              LearningObjective(
                code: '1.1',
                title: 'Find composite and inverse functions',
              ),
            ],
          ),
          Chapter(
            title: 'Differentiation',
            objectives: [
              LearningObjective(
                code: '2.1',
                title: 'Differentiate powers of x',
              ),
              LearningObjective(
                code: '2.2',
                title: 'Find stationary points and their nature',
              ),
            ],
          ),
        ],
      ),
      CourseSection(
        title: 'Mechanics',
        chapters: [
          Chapter(
            title: 'Kinematics',
            objectives: [
              LearningObjective(
                code: '3.1',
                title: 'Use the constant acceleration (suvat) equations',
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  Course(
    title: 'Physics (9702)',
    description: 'Kinematics, fields, quantum physics and practical skills.',
    qualification: Qualification.aLevel,
    videos: 5,
    addedOn: DateTime(2026, 10, 8),
    curriculum: const [
      CourseSection(
        title: 'AS Level',
        chapters: [
          Chapter(
            title: 'Kinematics',
            objectives: [
              LearningObjective(
                code: '1.1',
                title: 'Derive the equations of motion',
              ),
            ],
          ),
          Chapter(
            title: 'Waves',
            objectives: [
              LearningObjective(
                code: '2.1',
                title: 'Describe progressive and stationary waves',
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  Course(
    title: 'Economics (9708)',
    description: 'Micro and macroeconomics, markets and government policy.',
    qualification: Qualification.aLevel,
    videos: 0,
    addedOn: DateTime(2026, 7, 30),
    // A section with no chapters yet, so we can see the empty state.
    curriculum: const [
      CourseSection(title: 'Basic economic ideas', chapters: []),
    ],
  ),
];
