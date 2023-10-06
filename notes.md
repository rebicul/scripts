# clearVarlogs.sh
> The clearVarLogs.sh script is a shell script designed to automate the cleanup of the /var/log directory on a weekly basis. It is intended to be set up as a Cron job. Implementation starts on October 6th.

## Questions for Jon
- would be better to identify by mount first then by location using findmnt -T /var/log. Or by using df -h then grepping for /var* and going off the results?
- is storing the clearVarLogs.sh file in `/usr/local/bin/` or `/usr/local/sbin`?
- is it okay to make the clearVarLogs.sh executable using `chmod +x`?

## Checklist
- check to see if `/usr/local/bin/` is owned by root
- test self deleting shell script to see if it works
- implement [self-deleting shell script](https://stackoverflow.com/questions/8981164/self-deleting-shell-script)
- compare the findmnt -T /[folder] output and see if it could be an easier way to identify /var/log
- test automation script section `df -h | grep "/var/*"` vs `df -h | grep "/var*"` on a box with multiple var results to see if it affect functionality
- instead of prompting for username, first line of script should pwd home directory and save the path into a variable to use later
- what do associative arrays look like in code?