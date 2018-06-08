# Source: https://blogs.msdn.microsoft.com/laps/2015/05/06/laps-and-machine-reinstalls/

#Get NetBIOS domain name
$Info=new-object -com ADSystemInfo
$t=$info.GetType()

$domainName=$t.InvokeMember("DomainShortName","GetProperty",$null,$info,$null)
$computerName=$env:computerName

#translate domain\computername to distinguishedName
$translator = new-object -com NameTranslate
$t = $translator.gettype()
$t.InvokeMember(“Init”,”InvokeMethod”,$null,$translator,(3,$null)) #resolve via GC
$t.InvokeMember(“Set”,”InvokeMethod”,$null,$translator,(3,”$domainName\$ComputerName`$”))
$computerDN=$t.InvokeMember(“Get”,”InvokeMethod”,$null,$translator,1)

#connect to computer object
$computerObject= new-object System.DirectoryServices.DirectoryEntry("LDAP://$computerDN")

#clear password expiration time
($computerObject.'ms-Mcs-AdmPwdExpirationTime').Clear()

$computerObject.CommitChanges()