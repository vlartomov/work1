#!/usr/bin/expect -f

set HNAME [lindex $argv 0]

#SSH connection to remote host
spawn ssh -t ubuntu@$HNAME

# Expect password prompt
expect {
    "ubuntu@$HNAME's password:" {
        # Send password
        send "ubuntu\r"

        # Expect password change prompt
        expect {
            "Current password:" {
                # Send current password
                send "ubuntu\r"

                # Expect new password prompt
                expect "New password:"
                # Send new password
                send "3tango11!!\r"

                # Expect confirmation prompt
                expect "Retype new password:"
                # Send new password confirmation
                send "3tango11!!\r"
            }
            "Permission denied, please try again." {
                # Send alternative password
                send "3tango11!!\r"
            }
            timeout {
                # Handle timeout, i.e., when neither expected prompt is encountered
                send_user "Timeout occurred. Expected prompt not found.\n"
                exit 1
            }
        }
    }
    timeout {
        # Handle timeout, i.e., when "ubuntu@$HNAME's password:" prompt is not encountered
        send_user "Timeout occurred. Expected prompt not found.\n"
        exit 1
    }
}

# finish the ubuntu's part
expect eof

# Send command to switch to root user
send "sudo su\r"

# Send command to create root user and password
send "passwd root\r"

# Expect password request
expect "New password:\r"

# Send root password
send "3tango\r"

# Expect retyped password
expect "Retype new password:\r"

# Send root password
send "3tango\r"

# finish the script
expect eof
