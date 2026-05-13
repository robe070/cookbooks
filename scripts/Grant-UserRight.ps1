# This script does automatically what the following manual process does:
# To manually change (grant or revoke) the SeBackupPrivilege ("Back up files and directories") user right for a user (e.g., PCXUSER2) on the win2025 instance without any script:
# Press Win + R, type secpol.msc, press Enter → Local Security Policy opens.
# Expand Security Settings → Local Policies → User Rights Assignment.
# In the right pane, double-click Back up files and directories.
# Click Add User or Group…
# Type the username (e.g., PCXUSER2 or .\PCXUSER2 for local account) → Check Names → OK.
# To revoke: Select the user in the list → Remove.
# Click Apply → OK.
# Reboot the instance (or log off/on the affected user) for the change to take effect.
function Grant-UserRight {
    param (
        [string]$UserName,
        [string[]]$Rights
    )

    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        using System.Text;

        public class LsaUtility {
            [StructLayout(LayoutKind.Sequential)]
            private struct LSA_UNICODE_STRING {
                public UInt16 Length;
                public UInt16 MaximumLength;
                public IntPtr Buffer;
            }

            [StructLayout(LayoutKind.Sequential)]
            private struct LSA_OBJECT_ATTRIBUTES {
                public int Length;
                public IntPtr RootDirectory;
                public LSA_UNICODE_STRING ObjectName;
                public UInt32 Attributes;
                public IntPtr SecurityDescriptor;
                public IntPtr SecurityQualityOfService;
            }

            private const uint POLICY_LOOKUP_NAMES = 0x00000800;
            private const uint POLICY_CREATE_ACCOUNT = 0x00000010;

            [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
            private static extern uint LsaOpenPolicy(
                ref LSA_UNICODE_STRING SystemName,
                ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
                uint DesiredAccess,
                out IntPtr PolicyHandle
            );

            [DllImport("advapi32.dll", SetLastError = true)]
            private static extern uint LsaAddAccountRights(
                IntPtr PolicyHandle,
                IntPtr AccountSid,
                LSA_UNICODE_STRING[] UserRights,
                uint CountOfRights
            );

            [DllImport("advapi32.dll")]
            private static extern void LsaClose(IntPtr ObjectHandle);

            [DllImport("advapi32.dll", SetLastError = true)]
            private static extern bool LookupAccountName(
                string lpSystemName,
                string lpAccountName,
                [MarshalAs(UnmanagedType.LPArray)] byte[] Sid,
                ref uint cbSid,
                StringBuilder ReferencedDomainName,
                ref uint cchReferencedDomainName,
                out uint peUse
            );

            private static LSA_UNICODE_STRING InitLsaString(string s) {
                if (s == null) s = "";
                ushort length = (ushort)(s.Length * UnicodeEncoding.CharSize);
                LSA_UNICODE_STRING lsaString = new LSA_UNICODE_STRING();
                lsaString.Buffer = Marshal.StringToHGlobalUni(s);
                lsaString.Length = length;
                lsaString.MaximumLength = (ushort)(length + UnicodeEncoding.CharSize);
                return lsaString;
            }

            public static void GrantRights(string accountName, string[] rights) {
                IntPtr policyHandle = IntPtr.Zero;
                uint cbSid = 0;
                uint cchDomain = 0;
                uint peUse = 0;
                StringBuilder domainName = new StringBuilder();
                byte[] sid = null;

                // Get SID size
                LookupAccountName(null, accountName, null, ref cbSid, domainName, ref cchDomain, out peUse);
                sid = new byte[cbSid];
                domainName = new StringBuilder((int)cchDomain + 1);

                if (!LookupAccountName(null, accountName, sid, ref cbSid, domainName, ref cchDomain, out peUse)) {
                    throw new Exception("LookupAccountName failed: " + Marshal.GetLastWin32Error());
                }

                IntPtr sidPtr = Marshal.AllocHGlobal((int)cbSid);
                Marshal.Copy(sid, 0, sidPtr, (int)cbSid);

                LSA_UNICODE_STRING systemName = new LSA_UNICODE_STRING();
                LSA_OBJECT_ATTRIBUTES objectAttributes = new LSA_OBJECT_ATTRIBUTES();
                objectAttributes.Length = Marshal.SizeOf(objectAttributes);

                uint status = LsaOpenPolicy(ref systemName, ref objectAttributes, POLICY_LOOKUP_NAMES | POLICY_CREATE_ACCOUNT, out policyHandle);
                if (status != 0) {
                    throw new Exception("LsaOpenPolicy failed: " + status);
                }

                LSA_UNICODE_STRING[] lsaRights = new LSA_UNICODE_STRING[rights.Length];
                for (int i = 0; i < rights.Length; i++) {
                    lsaRights[i] = InitLsaString(rights[i]);
                }

                status = LsaAddAccountRights(policyHandle, sidPtr, lsaRights, (uint)rights.Length);
                if (status != 0) {
                    throw new Exception("LsaAddAccountRights failed: " + status);
                }

                LsaClose(policyHandle);
                Marshal.FreeHGlobal(sidPtr);
                foreach (var r in lsaRights) {
                    if (r.Buffer != IntPtr.Zero) Marshal.FreeHGlobal(r.Buffer);
                }
            }
        }
"@

    try {
        [LsaUtility]::GrantRights($UserName, $Rights)
        Write-Host "Successfully granted rights $($Rights -join ', ') to $UserName"
    } catch {
        Write-Error "Failed to grant rights: $($_.Exception.Message)"
    }
}

Grant-UserRight -UserName "PCXUSER2" -Rights @( "SeBackupPrivilege")

