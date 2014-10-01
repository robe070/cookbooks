Module Module1

    Sub Main()

      Dim oProcess As New Process()
      Dim oStartInfo As New ProcessStartInfo("python.exe", "C:\Users\Robert.SYD\Documents\GitHub\cookbooks\CloudFormation\test.py")
      oStartInfo.UseShellExecute = False
      oStartInfo.RedirectStandardOutput = True
      oProcess.StartInfo = oStartInfo
      oProcess.Start()

      Dim sOutput As String
      Using oStreamReader As System.IO.StreamReader = oProcess.StandardOutput
         sOutput = oStreamReader.ReadToEnd()
      End Using
      Console.WriteLine(sOutput)

   End Sub

End Module
