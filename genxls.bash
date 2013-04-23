#!/usr/bin/env bash
B="/mnt/B/bea_res"
sqldb="/home/foranw/src/db-export/luna.sqlite3.db"

# print lunaid run date eyd path sex age

find "${B}/Data/Tasks/MGSEncode/Basic/" -type f -iname \*eyd | while read eyd; do
 
 path="$(dirname $eyd)"
 eyd="$(basename $eyd)"
 lunaid=$(echo "$path"|perl -slane 'print $1 if m:/(\d{5})/:' )
 run=$(echo "$eyd"   |perl -slane 'print $1 if m:[A-Za-z](\d).eyd:' )
 date=$(echo "$path" |perl -slane 'print $1 if m:/(\d{8})/:' )
 echo -en "$lunaid\t$date\t$run\t$eyd\t$path\t"
 echo "$(sqlite3  $sqldb "
  SELECT s.SexID, 
         (strftime('%s',v.VisitDate) - strftime('%s',s.DateOfBirth))/(60*60*24*365.25) as ageAtVisit
   FROM tVisitTasks as v 
        join tSubjectInfo as s 
        on s.LunaID= v.LunaID
   where MGSencode == 1 and 
         strftime('%Y%m%d',v.VisitDate) like '$date' and
         s.LunaID like '$lunaid'
 " | sed 's/|/	/')"
done | sort -k1,2n |  perl -slane '
 $a{$F[0]}{$F[1]}=1;
 print join("\t",@F[0..1],scalar(keys %{$a{$F[0]}}),@F[2..$#F])
' | tee subjectsID_date_run_visit_eyd_path_sex_age.txt
