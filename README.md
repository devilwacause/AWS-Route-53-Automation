# AWS-Route-53-Automation
AWS Route 53 A Record Automation with Changing IP

INFORMATION
AWS changes your IP address for non Elastic IP bound EC2 instances upon restart.  When dealing with development resources that you've assigned a test domain to thru Route 53, 
you have to update the Route 53 record for the domain to reference the newly assigned public IPv4 address.  This can make cost saving measures such as turning off your development
server during night / weekends an extra chore as the domain must be updated whenever the system is started the following day / weekday.

In my case, we automated shutting down our development servers for web development every night at 6pm, and starting them up at 6am M-F.  I quickly realized I was going to have to 
automate the Route 53 updates - or spend a good bit of my morning updating Route 53 records for our web dev team.


PURPOSE:

Automates the update of Route 53 hosted zones when working with development EC2 instances that are rebooted either on schedule, or manually.

REQUIREMENTS:

If you use the install script, these will be checked before allowing you to install.

OS: Linux

Web Server: Apache (for now, will include nginx at later time)

Software: 

  AWS CLI  - https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html  
  
  JQ - Shell Based JSON manipulation.  sudo apt-get install jq (Ubuntu)
  





