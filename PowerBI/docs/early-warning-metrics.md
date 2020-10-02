# Early Warning Metrics - Power BI Starter Kit

December 18, 2018

* [Solution Overview](readme.md)
* [Deployment](deployment.md)
* [Technical Details](technical-details.md)
* Early Warning Metrics

## <a name='TableofContents'></a>Table of Contents

<!-- vscode-markdown-toc -->
* [Introduction](#Introduction)
* [Understanding Early Warning Categories](#UnderstandingEarlyWarningCategories)
    * [On Track](#OnTrack)
    * [Early Warning](#EarlyWarning)
    * [At-Risk](#At-Risk)
* [Overall Indicator](#OverallIndicator)
    * [Attendance Indicator](#AttendanceIndicator)
        * [Total Days Enrolled](#TotalDaysEnrolled)
        * [Days Absent](#DaysAbsent)
        * [Attendance Indicator Thresholds](#AttendanceIndicatorThresholds)
    * [Behavior Indicator](#BehaviorIndicator)
        * [Behavior Indicator Thresholds](#BehaviorIndicatorThresholds)
    * [Grade Indicator](#GradeIndicator)
        * [Overall Grade](#OverallGrade)
        * [Math Grade](#MathGrade)
        * [English Grade](#EnglishGrade)
        * [Grading Period](#GradingPeriod)
        * [Grade Indicator Threshold](#GradeIndicatorThreshold)

<!-- vscode-markdown-toc-config
    numbering=false
    autoSave=true
    /vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->

## <a name='Introduction'></a>Introduction
Early warning in the context of this project is based on the Balfanz model for
defining early warning. The various calculations based on this model are
configurable through the tabular model to support any model of early warning or
at risk categories based on grades, attendance and behavior.

## <a name='UnderstandingEarlyWarningCategories'></a>Understanding Early Warning Categories

There are three categories that students can fall into:

1. Student is on track and should be graduating on time.
2. Student is off track and is failing one or more of the predictors.
3. Student is almost off track. These students have not failed one of the
   predicting metrics but are reasonably close. This category is known as Early
   Warning.

### <a name='OnTrack'></a>On Track

A student in this category is passing all of the predicting metrics, and
according to the Balfanz Model, is not at risk for late graduation.

### <a name='EarlyWarning'></a>Early Warning

A student in this category is within a predefined threshold (5-15%) of failing a
predicting measure. Students that are considered Early Warning should be
monitored to prevent falling into the At-Risk category. These thresholds are:

* Daily Attendance Rate of less than 88 percent;
* More than 2 School Code of Conduct Violations;
* A failing Math Grade (≤ 72 and > 65);
* A failing English / English Language Arts Grade (≤ 72 and > 65)

### <a name='At-Risk'></a>At-Risk

A student in this category is failing one of more of the predicting metrics:

* Daily Attendance Rate of less than 80 percent;
* More than 5 School Code of Conduct Violations;
* One or more State Reportable Offense Violations;
* A failing Math Grade (≤ 65);
* A failing English / English Language Arts Grade (≤ 65)

Students that are considered At-Risk have a 15-25% chance of graduating high
school within one year of expected graduation, based on the Balfanz Model.

## <a name='OverallIndicator'></a>Overall Indicator

A student’s overall indicator is a rollup of the three other indicators
(Attendance, Grades, Behavior). It will default to the most severe level, in the
case that they are mixed (e.g. A student with a failing math grade but perfect
attendance will show as ‘At-Risk’).

### <a name='AttendanceIndicator'></a>Attendance Indicator

Attendance is a percentage, based on the following formula:

```
(Total Days Enrolled - Days Absent) / Total Days Enrolled
```

Each of these pieces can be broken down in to their own definition.

#### <a name='TotalDaysEnrolled'></a>Total Days Enrolled

This is the total number of days a student is expected to be in attendance at
school. This calculation takes into consideration the number of days that were
actually instructional or make-up days, as well as the possibility that a
student enrolled or withdrew from school during the year.

In order to accomplish this, we take the intersection of two lists of dates:

1. The list of dates that the school marked as an ‘Instructional Day’ or
   ‘Make-up Day’ based on the `edfi.CalendarDate` table and corresponding
   `edfi.CalendarEventType[CodeValue]`.
2. The list of dates, starting from the student’s `[EntryDate]` as marked in the
   `edfi.StudentSchoolAssociation` table, and ending at either the
   `[ExitWithdrawDate]` or last date in the school calendar.

#### <a name='DaysAbsent'></a>Days Absent

This is the total number of days a student was marked absent from school, based
on the `[AttendanceEventCategoryType]` of ‘Excused Absence’ or ‘Unexcused
Absence’. There are two cases that this considers:

1. If the student is marked absent in their homeroom, based on the
   edfi.StudentSectionAttendanceEvent table.
2. If the student is marked absent from school, based on the
   edfi.StudentSchoolAttendanceEvent table.

The calculation will default to checking a student’s homeroom attendance - if it
is null, the second case will be checked.

#### <a name='AttendanceIndicatorThresholds'></a>Attendance Indicator Thresholds

The default thresholds in the Early Warning System solution are:

| Indicator | Calculation |
| --------- | ----------- |
| At-Risk | Attendance Rate < 80.00% |
| Early Warning | Attendance Rate < 88.00% |
| On Track | Attendance Rate >= 88.00% |

### <a name='BehaviorIndicator'></a>Behavior Indicator

Behavior calculations will not be displayed, although they are included in the
overall student indicator. This is simply the count of school and state offenses
from the `edfi.DisciplineIncident`, `edfi.StudentDisciplineIncidentAssociation`,
and associated tables.

#### <a name='BehaviorIndicatorThresholds'></a>Behavior Indicator Thresholds
The default thresholds in the Early Warning System solution are:

| Indicator | Calculation |
| --------- | ----------- |
| At-Risk | State Offenses >= 1  OR  School Offenses > 5 |
| Early Warning | No State Offenses  AND  School Offenses > 2 |
| On Track | No State Offenses  AND  School Offenses <= 2 |

### <a name='GradeIndicator'></a>Grade Indicator

Grades are broken up into three categories: Overall, English, and Math. Only
English and Math grades are included in the student indicator. These
calculations all make use of the [NumericGradeEarned] column recorded in the
edfi.Grade table. For school grade levels that use letter grades, an equivalent
numeric grade is used based on the scale below.

| Letter | Grade Range |
| ------ | ----------- |
| A | 90 - 100 |
| B | 80 - 89 |
| C | 70 - 79 |
| D | 60 - 69 |
| F | < 60 |

The current model uses the middle of each range for grades A through D for
metric calculations (e.g. A = 95, B = 85, … F = 55). This translation from
letter to numeric grade is configurable in the
`analytics_config.LetterGradeTranslation` table.

#### <a name='OverallGrade'></a>Overall Grade

Overall grades are the average of all `edfi.Grade[NumericGradeEarned]` for a
particular section and grading period.

#### <a name='MathGrade'></a>Math Grade

Math grades are the average of all `edfi.Grade[NumericGradeEarned]` for a
particular section and grading period, where the corresponding course’s
`edfi.AcademicSubjectType[CodeValue]` is “Mathematics”.

#### <a name='EnglishGrade'></a>English Grade

English grades are the average of all `edfi.Grade[NumericGradeEarned]` for a
particular section and grading period, where the corresponding course’s
`edfi.AcademicSubjectType[CodeValue]` is “English Language Arts”, “Reading”, or
“Writing”.

#### <a name='GradingPeriod'></a>Grading Period

The grade calculations are based on grades assigned at the unit of a “grading
period” as defined in the GradeType table (`GradeType.CodeValue` = “Grading
Period”). For example, this might be a six week grading period or another time
unit for a progress report.

#### <a name='GradeIndicatorThreshold'></a>Grade Indicator Threshold

The default thresholds for the Ed-Fi Early Warning solution are:

| Indicator | Calculation |
| --------- | ----------- |
| At-Risk | English Grade < 65.00  OR  Math Grade < 65.00 |
| Early Warning | English Grade < 72.00  OR  Math Grade < 72.00 |
| On Track | English Grade >= 72.00 AND Math Grade >= 72.00 |

Grades that show up as blank are not the same as grades that are an explicit
zero. The Early Warning Indicators take this into consideration when flagging a
student as Early Warning or At Risk.