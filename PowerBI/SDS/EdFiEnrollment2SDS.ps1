<# 
© 2017 Ed-Fi Alliance, LLC. All Rights Reserved
www.Ed-Fi.org

This script will connect to an Ed-Fi API specified in the parameters sent in to the function call described below. 
When setting up the SDS Profile, the Student Data Sync files created with this script will NOT have the following fields: (so be sure to not include them in the Profile setup)

school.csv
	Missing Column - School Number
	Missing Column - Grade Low
	Missing Column - Grade High
	Missing Column - Country
	Missing Column - Zone
===========================================================================
student.csv
	Missing Column - Student Number
	Missing Column - Mailing Latitude
	Missing Column - Mailing Longitude
	Missing Column - Mailing Country
	Missing Column - Residence Latitude
	Missing Column - Residence Longitude
	Missing Column - Residence Country
	Missing Column - FederalRace
	Missing Column - Status
===========================================================================
teacher.csv
	Missing Column - Teacher Number
	Missing Column - Status
	Missing Column - Middle Name
	Missing Column - Qualification
===========================================================================
section.csv
	Missing Column - Section Number
	Missing Column - Course SIS ID
	Missing Column - Periods
    Missing Column - Status
===========================================================================


******** IMPORTANT *************
This script is supplied as a starting point. The Password field must be populated to upload the student and teacher file
This script generates the passwords as p@ssWord1, but can be set using the variable below this comment section
********************************


This script uses the following function and parameters to create the Student Data Sync file from an Ed-Fi API Instance

Function Build-SDS-CsvFiles
-apiRootUri (Alias -u) this is the uri root for the api to be called

-apiKey (Alias -k) the key for api authorization

-apiSecret (Alias -s) the API Secret for api authorization

-outputFilesPath (Alias -p) the local computer path to write the Student Data Sync Files

-localEducationAgencyId (Alias -l) the local education agency to build the files from


Usage:
To use this navigate to the folder that contains this file and load this file by calling it from the pwershell command line. Then call the function as described above

Examples calls

Build-SDS-CsvFiles -apiRootUri "http://localhost:54746/" -apiKey "vKkBahDXb0xi" -apiSecret "lytBIGmiVwez5uFGdKGJgGPh" -outputFilesPath "C:\sds\Glendale" -localEducationAgencyId "867530"


Build-SDS-CsvFiles -apiRootUri "https://api.ed-fi.org/api/" -apiKey "RvcohKz9zHI4" -apiSecret "E1iEFusaNf81xzCxwHfbolkC" -outputFilesPath "C:\sds\EdFi2SDS" -localEducationAgencyId "255901"
Build-SDS-CsvFiles -u "https://api.ed-fi.org/api/" -k "RvcohKz9zHI4" -s "E1iEFusaNf81xzCxwHfbolkC" -p "C:\sds\EdFi2SDS" -l "255901"

Notes:
Section Name is calculated using the Period name and the local course code because the Ed-Fi Standard does not define a title or name for the section
Section sis id is the Ed-Fi id
Section Name is the Ed-Fi uniqueSectionCode
Course SIS ID is the Ed-Fi id

#>

#script wide variables
$StudentTeacherPassword = "p@ssWord1"


function Get-Course-Id-Name-Description($courseOfferingReferenceId, $apiUri, $bearer)
{
    $courseInfo = New-Object System.Object
    $courseInfo | Add-Member -Type NoteProperty -Name "id" -Value ""
    $courseInfo | Add-Member -Type NoteProperty -Name "courseName" -Value ""
    $courseInfo | Add-Member -Type NoteProperty -Name "courseDescription" -Value ""

    $courseOfferingResponse = Invoke-RestMethod -uri "$($apiUri)/api/v2.0/2017/courseOfferings/$($courseOfferingReferenceId)" -ContentType "application/json" -Method Get -Headers $bearer
    if($courseOfferingResponse){
        $courseResponse = Invoke-RestMethod -uri "$($apiUri)/api/v2.0/2017$($courseOfferingResponse.courseReference.link.href)" -ContentType "application/json" -Method Get -Headers $bearer
        if($courseResponse){
            $courseInfo."courseName" = $courseResponse.id
            $courseInfo."courseName" = $courseResponse.title
            $courseInfo."courseDescription" = $courseResponse.description
        }
    }
    return $courseInfo
}

function Get-Staff-Name-Email($staffUniqueId, $apiUri, $bearer)
{
    Write-Host "looking for staff information for staff unique id $($staffUniqueId)"
    $staffInfo = New-Object System.Object
    $staffInfo | Add-Member -type NoteProperty -name staffName -value ""
    $staffInfo | Add-Member -type NoteProperty -name staffEmail -value ""
    $response = Invoke-RestMethod -Uri "$($apiUri)/api/v2.0/2016/staffs?staffUniqueId=$($staffUniqueId)" -ContentType "application/json" -Method Get -Headers $bearer
    if($response){
        [String]$staffFullName = "$($response.firstName) $($response.lastSurName)"
        Write-Host "Found staff record for staff unique id $($staffUniqueId). Name is $($staffFullName)"
        $staffInfo.staffName = $staffFullName
        #find an email
        if($response.electronicMails){
            $response.electronicMails | ForEach-Object{
                    if($_.electronicMailType -eq "Work"){
                        Write-Host "found 'work' email address"
                        $staffInfo.staffEmail = $response.electronicMails[0].electronicMailAddress
                    }
                }
        }
    }
    return $staffInfo
}

function Get-Principal-Information($schoolId, $apiUri, $bearer)
{
    Write-Host "looking for principal info for school id $($schoolId)"
    $principalInfo = New-Object System.Object
    $principalInfo | Add-Member -type NoteProperty -name principalSisId -value ""
    $principalInfo | Add-Member -type NoteProperty -name principalName -value ""
    $principalInfo | Add-Member -type NoteProperty -name principalSecondaryEmail -value ""

    $result = Invoke-RestMethod -Uri "$($apiUri)/api/v2.0/2016/staffEducationOrganizationAssignmentAssociations?educationOrganizationId=$($schoolId)&staffClassificationDescriptor=Principal" -ContentType "application/json" -Method Get -Headers $bearer
    $result | ForEach-Object{
        if($result){
            Write-Host "found a principal for school Id $($_.staffReference.staffUniqueId)"
            $principalInfo.principalSisId = $_.staffReference.staffUniqueId
            $staffInfo = Get-Staff-Name-Email $_.staffReference.staffUniqueId $apiUri $bearer
            Write-Host "staff name is $($staffInfo.staffname)"
            $principalInfo.principalName = $staffInfo.staffName
            $principalInfo.principalSecondaryEmail = $staffInfo.staffEmail
        }
    }
    return $principalInfo
}

function Get-School-Phone($phoneNumbers)
{
    $response = ""
    Write-Host "Looking for a phone number...."
    if($phoneNumbers){
        $phoneNumbers | ForEach-Object {
            if($_.institutionTelephoneNumberType -eq "Main"){
                write-host "found 'Main' phone number"
                $response = $_.telephoneNumber
            }
        }
        if($response -eq "" -and $phoneNumbers.Count>0){
            $response = $phoneNumbers[0].telephoneNumber
        }
    }
    return $response
}

function Get-School-NCES-Id($identificationCodes)
{
    $response = ""
    Write-Host "Looking for NCES id...."
    if($identificationCodes){
        $identificationCodes | ForEach-Object {
            if($_.educationOrganizationIdentificationSystemDescriptor -eq "NCES"){
                write-host "found NCES id"
                $response = $_.identificationCode
            }
        }
    }
    return $response
}

function Get-School-Address($addresses)
{
    $addressObject = New-Object System.Object

    Write-Host "getting address...."
    if(-not($addresses) -or $addresses.Count -eq 0){
        write-host "addresses seems to be empty or null, returning null"
        $addressObject = $null
    }
    else
    {
        write-host "addresses count: $($addresses.Count)"
        #if there is only one address return it
        if($addresses.count -eq 1){
            $addressObject | Add-Member -type NoteProperty -name Address -value $addresses[0].streetNumberName
            $addressObject | Add-Member -type NoteProperty -name City -value $addresses[0].city
            $addressObject | Add-Member -type NoteProperty -name State -value $addresses[0].stateAbbreviationType
            $addressObject | Add-Member -type NoteProperty -name Zip -value $addresses[0].postalCode
            Write-Host "only one address, returning it"
        }
        else
        {
            #if there is more than one address this code will favor "physical" over others if there is no physical it will return the first one in the list
            $addresses | ForEach-Object{
                    Write-Host "the address type is $($_.addressType)."
                    if($_.addressType -eq "Physical"){
                        $addressObject | Add-Member -type NoteProperty -name Address -value $_.streetNumberName
                        $addressObject | Add-Member -type NoteProperty -name City -value $_.city
                        $addressObject | Add-Member -type NoteProperty -name State -value $_.stateAbbreviationType
                        $addressObject | Add-Member -type NoteProperty -name Zip -value $_.postalCode
                        Write-Host "Found 'physical' address, returning it"
                    }
                }
        }

        #if addressObject is still null return first item
        if(-not($addressObject)){
            $addressObject | Add-Member -type NoteProperty -name Address -value $addresses[0].streetNumberName
            $addressObject | Add-Member -type NoteProperty -name City -value $addresses[0].city
            $addressObject | Add-Member -type NoteProperty -name State -value $addresses[0].stateAbbreviationType
            $addressObject | Add-Member -type NoteProperty -name Zip -value $addresses[0].postalCode
        }
    }
    Write-Host "returning"
    return $addressObject
}

function Get-School($schoolIdsArray, $schoolId, $apiUri, $bearer)
{
    Write-Host "Checking school id $($schoolId)"
    #check if the school exists in the array already, return the school object to be added to the school array'
    if($schoolIdsArray -contains $schoolId){
        Write-Host "School $($schoolId) already in the list..."
        $schoolObject = $null
    }
    else{
        #populate schools object for file export
        Write-Host "School $($schoolId) not in the list, adding it"

        $schoolResponse = Invoke-RestMethod -uri "$($apiUri)/api/v2.0/2017/enrollment/schools?schoolId=$($schoolId)" -ContentType "application/json" -Method Get -Headers $bearer    
        
        #debug output
        #Write-Host ($schoolResponse | Format-Table | Out-String)

        $schoolObject = New-Object System.Object
        $schoolObject | Add-Member -type NoteProperty -name "SIS ID" -value $schoolResponse.schoolId
        $schoolObject | Add-Member -type NoteProperty -name Name -value $schoolResponse.nameOfInstitution
        $schoolObject | Add-Member -type NoteProperty -name "State ID" -value $schoolResponse.stateOrganizationId

        $address = Get-School-Address $schoolResponse.addresses
        
        if($address){
            Write-Host "Address for $($schoolResponse.nameOfInstitution) returned not null and has a type of..."
            Write-Host $address.GetType()
            $schoolObject | Add-Member -type NoteProperty -name Address -value $address.Address
            $schoolObject | Add-Member -type NoteProperty -name City -value $address.City
            $schoolObject | Add-Member -type NoteProperty -name State -value $address.State
            $schoolObject | Add-Member -type NoteProperty -name Zip -value $address.Zip
        }
        else {
            #address is null, but want to add the properties with empty string for now
            Write-Host "Address for $($schoolResponse.nameOfInstitution) is null"
            $schoolObject | Add-Member -type NoteProperty -name Address -value ""
            $schoolObject | Add-Member -type NoteProperty -name City -value ""
            $schoolObject | Add-Member -type NoteProperty -name State -value ""
            $schoolObject | Add-Member -type NoteProperty -name Zip -value ""
        }
        
        $ncesId = Get-School-NCES-Id $schoolResponse.identificationCodes
        $schoolObject | Add-Member -type NoteProperty -name "School NCES_ID" -value $ncesId

        $schoolPhone = Get-School-Phone $schoolResponse.institutionTelephones
        $schoolObject | Add-Member -type NoteProperty -name Phone -value $schoolPhone

        Write-Host "getting principal for school with schoolId of $($schoolResponse.schoolId)"
        $principalInfo = Get-Principal-Information $schoolResponse.schoolId $apiUri $bearer
        Write-Host ($principalInfo | Format-Table | Out-String)
        $schoolObject | Add-Member -type NoteProperty -name "Principal SIS ID" -value $principalInfo.principalSisId
        $schoolObject | Add-Member -type NoteProperty -name "Principal Name" -value $principalInfo.principalName
        $schoolObject | Add-Member -type NoteProperty -name "Principal Secondary Email" -value $principalInfo.principalSecondaryEmail
    }

    return $schoolObject
}
function Get-Student-GraduationYear($schoolAssociationid, $apiUri, $bearer)
{
    #Write-Host "Getting Student Graduation Year for school association id $($schoolAssociationid)."
    $graduationYearResponse = ""
    $studentSchoolAssociationResponse = Invoke-RestMethod -uri "$($apiUri)/api/v2.0/2017/studentSchoolAssociations/$($schoolAssociationid)" -ContentType "application/json" -Method Get -Headers $bearer
    if($studentSchoolAssociationResponse){
        $graduationYearResponse = $studentSchoolAssociationResponse.graduationPlanReference.graduationSchoolYear
    }
    return $graduationYearResponse
}

function Get-Student($sdsStudentsArray, $student, $schoolSisId, $apiUri, $bearer)
{
    #check if the student exists in the array already, return the student object to be added to the school array or null'
    if($sdsStudentsArray."SIS ID" -contains $student.studentUniqueId){
        Write-Host "Student with id $($student.id) already in the list..."
        $studentObject = $null
    }
    else{
        Write-Host "student id $($student.id) not found in the list, adding it"
        #initialize object
        $studentObject = New-Object System.Object
        $studentObject | Add-Member -type NoteProperty -name "SIS ID" -value ""
        $studentObject | Add-Member -type NoteProperty -name "School SIS ID" -value ""
        $studentObject | Add-Member -type NoteProperty -name "First Name" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Middle Name" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Last Name" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Username" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Password" -value ""
        $studentObject | Add-Member -type NoteProperty -name "State ID" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Secondary Email" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Grade" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Mailing Address" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Mailing City" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Mailing State" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Mailing Zip" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Residence Address" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Residence City" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Residence State" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Residence Zip" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Gender" -value ""
        $studentObject | Add-Member -type NoteProperty -name "Birthdate" -value ""
        $studentObject | Add-Member -type NoteProperty -name "ELL Status" -value "False"
        $studentObject | Add-Member -type NoteProperty -name "Graduation Year" -value "False"

        #populate object
        $studentObject."School SIS ID" = $schoolSisId
        $studentObject."SIS ID" = $student.studentUniqueId
        $studentObject."First Name" = $student.firstName
        $studentObject."Middle Name" = $student.middleName
        $studentObject."Last Name" = $student.lastSurname
        [string]$loginId = $student.loginId
        if($loginId.Contains(" ")){
            $loginId = $loginId.Replace(" ","")
        }
        if(-not($loginId)){
            $loginId = Get-Username $student.firstName $student.lastSurname $sdsStudentsArray
        }
        $studentObject."Username" = $loginId
        $studentObject."Password" = $StudentTeacherPassword
        $studentObject."Gender" = $student.sexType
        $studentObject."Birthdate" = $student.birthDate
        if($student.electronicMails){
            $studentObject."Secondary Email" = $student.electronicMails[0].electronicMailAddress
        }
        if($student.addresses){
            $studentObject."Mailing Address" = $student.addresses[0].streetNumberName
            $studentObject."Mailing City" = $student.addresses[0].city
            $studentObject."Mailing State" = $student.addresses[0].stateAbbreviationType
            $studentObject."Mailing Zip" = $student.addresses[0].postalCode
            $studentObject."Residence Address" = $student.addresses[0].streetNumberName
            $studentObject."Residence City" = $student.addresses[0].city
            $studentObject."Residence State" = $student.addresses[0].stateAbbreviationType
            $studentObject."Residence Zip" = $student.addresses[0].postalCode
        }
        if($student.schoolAssociations){
            $studentObject."Grade" = $student.schoolAssociations.gradeLevelType
        }
        if($student.indicators){
            $student.indicators | ForEach-Object{
                if($student.indicatorName -eq "ELL"){
                    $studentObject."ELL Status" = $student.indicator
                }
            }
        }
        if($student.identificationCodes){
            $student.identificationCodes | ForEach-Object{
                if($student.staffIdentificationSystemType -eq "State"){
                    $studentObject."State ID" = $student.identificationCode
                }
            }
        }
        #get graduation year
        if($student.schoolAssociations){
            $graduationYear = Get-Student-GraduationYear $_.schoolAssociations.id $apiUri $bearer
            $studentObject."Graduation Year" = $graduationYear
        }
    }
    return $studentObject
}

function Get-Staff-Position-Title($staffUniqueId, $schoolSisId, $apiUri, $bearer)
{
    $positionTitleResponse = ""
    $staffEdOrgAssignmentAssocResponse = Invoke-RestMethod -uri "$($apiUri)/api/v2.0/2017/staffEducationOrganizationAssignmentAssociations?staffUniqueId=$($staffUniqueId)&educationOrganizationId=$($schoolSisId)" -ContentType "application/json" -Method Get -Headers $bearer
    if($staffEdOrgAssignmentAssocResponse){
        $positionTitleResponse = $staffEdOrgAssignmentAssocResponse.positionTitle
    }
    return $positionTitleResponse
}

function Get-Username($firstName, $lastName, $sdsPersonArray)
{
    $loginId = "$($firstName).$($lastName)"
    if($sdsPersonArray."Username" -contains $loginId){
        $loginIdCount=1
        while($sdsPersonArray."Username" -contains "$($loginId)$($loginIdCount.ToString())"){
            $loginIdCount += 1
        }
        $loginId = "$($loginId).$($loginIdCount.ToString())"
    }
    $loginId = $loginId.Replace(" ","")
    if($loginId[-1] -eq '.'){
        $loginId = $loginId.Replace(".","")
    }
    if($loginId[0] -eq '.'){
         $loginId = $loginId.Replace(".","")
    }
    return $loginId
}
function Get-Teacher($sdsTeachersArray, $teacher, $schoolId, $apiUri, $bearer)
{
   # debugging statements
   # Write-Host "Get Teacher teacher id $($teacher.staffUniqueId)"
   # Write-Host ($sdsTeachersArray | Format-Table | Out-String)

    if($sdsTeachersArray."SIS ID" -contains $teacher.staffUniqueId){
        $teacherObject = $null
    }
    else{
        #initialize object
        $teacherObject = New-Object System.Object
        $teacherObject | Add-Member -type NoteProperty -name "SIS ID" -value ""
        $teacherObject | Add-Member -type NoteProperty -name "School SIS ID" -value ""
        $teacherObject | Add-Member -type NoteProperty -name "First Name" -value ""
        $teacherObject | Add-Member -type NoteProperty -name "Last Name" -value ""
        $teacherObject | Add-Member -type NoteProperty -name "Username" -value ""
        $teacherObject | Add-Member -type NoteProperty -name "Password" -value ""
        $teacherObject | Add-Member -type NoteProperty -name "Secondary Email" -value ""
        $teacherObject | Add-Member -type NoteProperty -name "State ID" -value ""
        $teacherObject | Add-Member -type NoteProperty -name "Title" -value ""
            
        #populate object
        $teacherObject."School SIS ID" = $schoolId
        $teacherObject."SIS ID" = $teacher.staffUniqueId
        $teacherObject."First Name" = $teacher.firstName
        $teacherObject."Last Name" = $teacher.lastSurname
        [string]$loginId = $teacher.loginId
        if($loginId.Contains(" ")){
            $loginId = $loginId.Replace(" ","")
        }
        if(-not($loginId)){
            $loginId = Get-Username $teacher.firstName $teacher.lastSurname $sdsTeachersArray
        }
        $teacherObject."Username" = $loginId
        $teacherObject."Password" = $StudentTeacherPassword
        if($_.electronicMails){
            $teacherObject."Secondary Email" = $teacher.electronicMails[0].electronicMailAddress
        }
        if($teacher.identificationCodes){
            $teacher.identificationCodes | ForEach-Object{
                if($teacher.staffIdentificationSystemType -eq "State"){
                    $teacherObject."State ID" = $teacher.identificationCode
                }
            }
        }
        #sget position title
        $positionTitle = Get-Staff-Position-Title $teacher.staffUniqueId $schoolId $apiUri $bearer
        $teacherObject."Title" = $positionTitle
    }
    return $teacherObject
}

function Get-Principal-As-Teacher($sdsTeachersArray, $principalSisid, $schoolSisId, $apiUri, $bearer)
{
    #get staff object
    $staffResponse = Invoke-RestMethod -uri "$($apiUri)/api/v2.0/2017/enrollment/staffs?staffUniqueId=$($principalSisid)" -ContentType "application/json" -Method Get -Headers $bearer    

    #call regular add get teacher
    if($staffResponse){
        Write-Host "found staff info for principal with id $($principalSisid)"
        $GetTeacherResponse = Get-Teacher $sdsTeachersArray $staffResponse $schoolSisId $apiUri $bearer
    }
    else{
        $GetTeacherResponse = $null
    }
    return $GetTeacherResponse
}

function Build-SDS-Files($filePath, $localEducationAgencyId, $apiUri, $bearer)
{
    #start
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Write-Output "Begin building SDS files at $(Get-Date)"
    Write-Host "Begin building Section and student/teacher section mapping files"
    
    #Get the guid for the local education agency id sent in
    $leaResponse = Invoke-RestMethod -uri "$($apiUri)/api/v2.0/2017/enrollment/localEducationAgencies?localEducationAgencyId=$($localEducationAgencyId)" -ContentType "application/json" -Method Get -Headers $bearer    
    $leaId = $leaResponse.id
    
    #initialize arrays that will be written out to csv
    $sdsSectionsArray = @()
    $sdsSchoolsArray = @()
    $sdsStudentsArray = @()
    $sdsTeachersArray = @()
    $studentEnrollmentArray = @()
    $teacherRosterArray = @()

    #initialize limit variable for paging
    $limit = 50

    #Get first page of section enrollments
    Write-Host "Getting section enrollments"
    $sectionEnrollmentsResponse = Invoke-RestMethod -uri "$($apiUri)/api/v2.0/2017/enrollment/localEducationAgencies/$($leaId)/sectionEnrollments?limit=$($limit)" -ContentType "application/json" -Method Get -Headers $bearer
    Write-Host "SectionEnrollments page 1 response object count $($sectionEnrollmentsResponse.count)"
    
    #initialize count variables
    $sectionEnrollmentsPageCount = 0
    $schoolCount = 0

    #while($sectionEnrollmentsResponse -and $sectionEnrollmentsPageCount -lt 5){
    while($sectionEnrollmentsResponse){
        $sectionEnrollmentsResponse | ForEach-Object{
            #Get the Section
            #initialize object
            $sectionObject = New-Object System.Object
            $sectionObject | Add-Member -type NoteProperty -name "SIS ID" -value ""
            $sectionObject | Add-Member -type NoteProperty -name "School SIS ID" -value ""
            $sectionObject | Add-Member -type NoteProperty -name "Section Name" -value ""
            #optional
            $sectionObject | Add-Member -type NoteProperty -name "Section Number" -value ""
            $sectionObject | Add-Member -type NoteProperty -name "Term SIS ID" -value ""
            $sectionObject | Add-Member -type NoteProperty -name "Term Name" -value ""
            $sectionObject | Add-Member -type NoteProperty -name "Term StartDate" -value ""
            $sectionObject | Add-Member -type NoteProperty -name "Term EndDate" -value ""
            $sectionObject | Add-Member -type NoteProperty -name "Course SIS ID" -value ""
            $sectionObject | Add-Member -type NoteProperty -name "Course Name" -value ""
            $sectionObject | Add-Member -type NoteProperty -name "Course Description" -value ""
            $sectionObject | Add-Member -type NoteProperty -name "Course Subject" -value ""

            #populate object
            $sectionObject."School SIS ID" = $_.SchoolReference.id
            $sectionObject."SIS ID" = $_.id
            $sectionObject."Section Number" = $_.uniqueSectionCode
            $sectionObject."Section Name" = "$($_.classPeriodReference.name) $($_.courseOfferingReference.localCourseCode) $($_.uniqueSectionCode) $($_.locationReference.classroomIdentificationCode)"
            $sectionObject."Term SIS ID" = $_.sessionReference.id
            $sectionObject."Term Name" = $_.sessionReference.termDescriptor
            $sectionObject."Term StartDate" = ([DateTime]$_.sessionReference.beginDate).ToShortDateString()
            $sectionObject."Term EndDate" = ([DateTime]$_.sessionReference.endDate).ToShortDateString()
            $sectionObject."Course Subject" = $_.academicSubjectDescriptor
            #get course name and description
            $courseNameDesc = Get-Course-Id-Name-Description $_.courseOfferingReference.id $apiUri $bearer
            if($courseNameDesc){
                $sectionObject."Course SIS ID" = $courseNameDesc."id"
                $sectionObject."Course Name" = $courseNameDesc."courseName"
                $sectionObject."Course Description" = $courseNameDesc."courseDescription"
            }

            #add section to array
            Write-Host "Adding section $($_.id) to the section array"
            $sdsSectionsArray += $sectionObject

            #add School to schools array
            $schoolIds = $sdsSchoolsArray."SIS ID"
            $GetSchoolResponse = Get-School $schoolIds $_.SchoolReference.schoolId $apiUri $bearer
            if($GetSchoolResponse){
                #increment school count
                $schoolCount += 1
                #add school to school array
                $sdsSchoolsArray += $GetSchoolResponse
                #Check if the principal is in the Teachers array
                if($GetSchoolResponse."Principal SIS ID"){
                    $GetPrincipalTeacherResponse = Get-Principal-As-Teacher $sdsTeachersArray $GetSchoolResponse."Principal SIS ID" $GetSchoolResponse."SIS ID" $apiUri $bearer
                    #add the prinicpal to the teacher file so that the principal user is created
                    if($GetPrincipalTeacherResponse){
                        $sdsTeachersArray += $GetPrincipalTeacherResponse
                    }
                }
            }

            #add studentEnrollments (Student section)
            $sectionId = $_.id
            $schoolSISId = $_.schoolReference.schoolId
            $_.students | ForEach-Object{
                #intitialize and populate object
                $studentEnrollment  = New-Object System.Object
                #sis id of the section which this script is using the section uniqie identifier from Ed-Fi
                $studentEnrollment | Add-Member -type NoteProperty -Name "Section SIS ID" -Value $sectionId
                #sis id of the student which in this script is the Student unique id
                $studentEnrollment | Add-Member -type NoteProperty -Name "SIS ID" -Value $_.studentUniqueId
                #add to array
                $studentEnrollmentArray += $studentEnrollment
                #add Students to the students array
                $GetStudentResponse = Get-Student $sdsStudentsArray $_ $schoolSISId $apiUri $bearer
                if($GetStudentResponse){
                    $sdsStudentsArray += $GetStudentResponse
                }
            }

            
            #add teacherRoster (teacher section)
            if($_.staff){
                #intitialize and populate object
                $teacherRoster  = New-Object System.Object
                #sis id of the section which this script is using the section uniqie identifier from Ed-Fi
                $teacherRoster | Add-Member -type NoteProperty -Name "Section SIS ID" -Value $sectionId
                #sis id of the teacher which in this script is the staff unique id
                $teacherRoster | Add-Member -type NoteProperty -Name "SIS ID" -Value $_.staff[0].staffUniqueId
                $teacherRosterArray += $teacherRoster
                
                #add teacher
                Write-Host "Calling Get Teacher with teacher id $($_.staff[0].staffUniqueId)"
                $GetTeacherResponse = Get-Teacher $sdsTeachersArray $_.Staff[0] $_.schoolReference.schoolId $apiUri $bearer
                #add the teacher object ot the teacher array
                if($GetTeacherResponse){
                    $sdsTeachersArray += $GetTeacherResponse
                }
            }

        }
        $sectionEnrollmentsPageCount += 1
        $sectionEnrollmentsResponse = Invoke-RestMethod -uri "$($apiUri)/api/v2.0/2017/enrollment/sectionEnrollments?offset=$($sectionEnrollmentsPageCount*$limit)&limit=$($limit)" -ContentType "application/json" -Method Get -Headers $bearer
        Write-Host "section enrollements request page $($sectionEnrollmentsPageCount+1) response object count $($sectionEnrollmentsResponse.count)"

        #rewrite for debugging to have the files rewritten for every iteration of a section
        $sdsSectionsArray | Export-Csv -Path "$($filePath)\section.csv" -NoTypeInformation
        $sdsSchoolsArray | Export-Csv -Path "$($filePath)\school.csv" -NoTypeInformation
        $studentEnrollmentArray | Export-Csv -Path "$($filePath)\studentEnrollment.csv" -NoTypeInformation
        $sdsStudentsArray | Export-Csv -Path "$($filePath)\student.csv" -NoTypeInformation
        $teacherRosterArray | Export-Csv -Path "$($filePath)\teacherRoster.csv" -NoTypeInformation
        $sdsTeachersArray | Export-Csv -Path "$($filePath)\teacher.csv" -NoTypeInformation
    }

    #write the final files

    #write sections csv file
    Write-Host "Sections object array with count of $($sdsSectionsArray.count)"
    Write-Host "writing sections.csv file"
    $sdsSectionsArray | Export-Csv -Path "$($filePath)\section.csv" -NoTypeInformation

    #write schools file
    Write-Host "school object array with count of $($sdsSchoolsArray.count)"
    Write-Host "writing schools.csv file"
    $sdsSchoolsArray | Export-Csv -Path "$($filePath)\school.csv" -NoTypeInformation

    #write studentEnrollment file
    Write-Host "Student Enrollments object array with count of $($studentEnrollmentArray.count)"
    Write-Host "writing studentEnrollment.csv file"
    $studentEnrollmentArray | Export-Csv -Path "$($filePath)\studentEnrollment.csv" -NoTypeInformation

    #write students file
    #students information and file
    Write-Host "Student object array with count of $($sdsStudentsArray.count)"
    Write-Host "writing students.csv file"
    $sdsStudentsArray | Export-Csv -Path "$($filePath)\student.csv" -NoTypeInformation

    #write teacherRoster (teacher section xref) file
    Write-Host "Teacher Roster object array with count of $($teacherRosterArray.count)"
    Write-Host "writing teacherRoster.csv file"
    $teacherRosterArray | Export-Csv -Path "$($filePath)\teacherRoster.csv" -NoTypeInformation

    #write teachers file
    Write-Host "Teacher object array with count of $($sdsTeachersArray.count)"
    Write-Host "writing teachers.csv file"
    $sdsTeachersArray | Export-Csv -Path "$($filePath)\teacher.csv" -NoTypeInformation

    Write-Output "Finished building SDS files at $(Get-Date)"
    $sw.Stop()
    Write-Output "time elapsed"
    $sw.Elapsed
}

function Get-Token($keyIn, $secretIn, $apiRootUri)
{
    #Get a token for the oath2 for the api a secret and key are needed
    #
    write-host "Begin Get-Token.."
    write-host "$($apiRootUri)/oauth/authorize?Client_id=$($keyIn)&Response_type=code"
    $result =  Invoke-WebRequest -Uri "$($apiRootUri)/oauth/authorize?Client_id=$($keyIn)&Response_type=code"
    $code = ConvertFrom-Json -InputObject $result.Content
    if($result.StatusCode -ne 200)
    {
        #error
        Write-Error ("invalid status code of ", $result.StatusCode -join " ")
        return false
    }

    Write-Host "Authorize code $($code.code)"

    $result = Invoke-RestMethod -uri "$($apiRootUri)/oauth/token" -Body "{'Client_id':'$($keyIn)','Client_secret':'$($secretIn)','Code':'$($code.code)','Grant_type':'authorization_code'}" -ContentType "application/json" -Method Post
    write-host "token response = $($result.access_token)"

    $access_token = $result.access_token
    
    write-host "End Get-Token - access_token $($access_token)"
    return $access_token
}

function Build-SDS-CsvFiles
{
<#
function description
#>
    [CmdletBinding()]
    Param(
        [Alias("u")]
        #uri root for the api to call
        [string]$apiRootUri = $( Read-Host "Please enter Ed-Fi API root uri (for example: https://api.ed-fi.org ) " ),

        [Alias("k")]
        #key for api
        [string]$apiKey = $( Read-Host "Please enter Ed-Fi API key " ),

        [Alias("s")]
        #API Secret
        [string]$apiSecret = $( Read-Host "Please enter Ed-Fi API secret  " ),

        [Alias("p")]
        [string]$outputFilesPath = $( Read-Host "Please enter Folder Path to write files " ),

        [Alias("l")]
        [string]$localEducationAgencyId = $( Read-Host "Please enter local education agency id " )
    )
    begin {
        $keepSignedIn = $true
        $msgLogCmdName =  $PSCmdlet.MyInvocation.MyCommand.Name
      }
    process {

        #trim trailing / if in uri root and folder path
        $apiRootUri = $apiRootUri.Trim('/')
        $outputFilesPath = $outputFilesPath.Trim('\')


        Write-Host "---post mod parameter values......---"
        Write-Host "api root $($apiRootUri)."
        Write-Host "key $($apiKey)."
        Write-Host "secret $($apiSecret)."
        Write-Host "csv folder $($outputFilesPath)."
        Write-Host "----------------------------------"
        Write-Host "bearer token $($env:bearerToken)."

        if(-not($env:bearerToken)){
            Write-Host "No bearer token found, authorizing....."
            $env:bearerToken = Get-Token $apiKey $apiSecret $apiRootUri
        }
        #create auth bearer header
        [System.Collections.IDictionary]$bearer = @{ "Authorization" = "Bearer $($env:bearerToken)" }
        
        
        #build files
        Build-SDS-Files $outputFilesPath $localEducationAgencyId $apiRootUri $bearer
    }
}


