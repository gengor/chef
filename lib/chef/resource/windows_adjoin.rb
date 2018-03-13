#
# Author:: John Snow (<jsnow@chef.io>)
# Copyright:: 2016-2018, John Snow
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef/resource"

class Chef
  class Resource
    class WindowsAdJoin < Chef::Resource
      resource_name :windows_adjoin
      provides :windows_adjoin

      description "Use the windows_adjoin resource to join a Windows Active Directory domain."
      introduced "14.0"

      property :domain_name, String,
               description: "",
               name_property: true

      property :dns_server, String,
               description: ""

      property :domain_user, String,
               description: ""

      property :domain_password, String,
               description: ""

      property :ou_path, String,
               description: ""

      property :set_dns, [TrueClass, FalseClass],
               description: "",
               default: true

      property :restart, [TrueClass, FalseClass],
               description: "",
               default: true

      action :join do
        unless on_domain?
          cmd = ""
          cmd << "$pswd = ConvertTo-SecureString"
          cmd << " \'#{new_resource.domain_password}\'"
          cmd << " -AsPlainText"
          cmd << " -Force;"
          cmd << "$credential = New-Object"
          cmd << " System.Management.Automation.PSCredential (\"#{new_resource.domain_user}\",$pswd);"
          cmd << "Add-Computer"
          cmd << " -DomainName #{new_resource.domain_name}"
          cmd << " -Credential $credential"
          cmd << " -OUPath \"#{new_resource.ou_path}\""  if new_resource.ou_path
          cmd << " -Restart" if new_resource.restart
          cmd << " -Force"

          powershell_script "join Active Directory domain #{new_resource.domain_name}" do
            code cmd
          end
        end

        if new_resource.set_dns && !dns_servers_set?
          cmd = ""
          cmd << "$CorrectDNS = #{new_resource.dns_server};"
          cmd << '$NIC = Get-NetAdapter | where {$_.Status -eq "Up"};'
          cmd << "$NIC | Set-DnsClientServerAddress -ServerAddresses $CorrectDNS"

          powershell_script "Configure DNS on the node" do
            code cmd
          end
        end
      end

      action_class do
        def on_domain?
          cmd = ""
          cmd << "$domain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).Name;"
          cmd << "$domain -eq \'#{new_resource.domain_name}\'"
          check = Mixlib::ShellOut.new("powershell.exe -command \"& {#{cmd}}\"").run_command
          check.stdout.match("True")
        end

        def dns_servers_set?
          cmd = ""
          cmd << '$NIC = Get-NetAdapter | where {$_.Status -eq \"Up\"};'
          cmd << "$DnsServers = $NIC | Get-DnsClientServerAddress -AddressFamily IPv4;"
          cmd << "$CorrectDNS = #{new_resource.dns_server};"
          cmd << "(Compare-Object $DnsServers.ServerAddresses $CorrectDNS -sync 0).Length -eq 0"
          check = Mixlib::ShellOut.new("powershell.exe -command \"& {#{cmd}}\"").run_command
          check.stdout.match("True")
        end
      end
    end
  end
end
