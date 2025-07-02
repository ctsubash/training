
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "NSLookup FQDN Resolver"
$form.Size = New-Object System.Drawing.Size(720, 620)
$form.StartPosition = "CenterScreen"

# Define base domains to try appending for FQDN resolution
$dnsSuffixes = @("example.com", "openai.com", "google.com", "microsoft.com")

# Input label
$label = New-Object System.Windows.Forms.Label
$label.Text = "Enter server names (e.g., www, mail, intranet):"
$label.Location = New-Object System.Drawing.Point(10, 10)
$label.Size = New-Object System.Drawing.Size(400, 20)
$form.Controls.Add($label)

# Input box
$inputBox = New-Object System.Windows.Forms.TextBox
$inputBox.Multiline = $true
$inputBox.ScrollBars = "Vertical"
$inputBox.Size = New-Object System.Drawing.Size(680, 100)
$inputBox.Location = New-Object System.Drawing.Point(10, 35)
$form.Controls.Add($inputBox)

# Output grid
$dataGrid = New-Object System.Windows.Forms.DataGridView
$dataGrid.Size = New-Object System.Drawing.Size(680, 320)
$dataGrid.Location = New-Object System.Drawing.Point(10, 140)
$dataGrid.ColumnCount = 3
$dataGrid.Columns[0].Name = "ServerName"
$dataGrid.Columns[1].Name = "FQDN"
$dataGrid.Columns[2].Name = "IPAddress(es)"
$dataGrid.ReadOnly = $true
$dataGrid.AllowUserToAddRows = $false
$dataGrid.RowHeadersVisible = $false
$form.Controls.Add($dataGrid)

# Run button
$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = "Resolve FQDN"
$runButton.Size = New-Object System.Drawing.Size(120, 30)
$runButton.Location = New-Object System.Drawing.Point(10, 480)
$form.Controls.Add($runButton)

# Export format dropdown
$exportLabel = New-Object System.Windows.Forms.Label
$exportLabel.Text = "Export Format:"
$exportLabel.Location = New-Object System.Drawing.Point(150, 486)
$form.Controls.Add($exportLabel)

$exportFormat = New-Object System.Windows.Forms.ComboBox
$exportFormat.Location = New-Object System.Drawing.Point(250, 482)
$exportFormat.Size = New-Object System.Drawing.Size(120, 25)
$exportFormat.DropDownStyle = "DropDownList"
$exportFormat.Items.AddRange(@("CSV", "XLSX", "TXT", "HTML"))
$exportFormat.SelectedIndex = 0
$form.Controls.Add($exportFormat)

# Export button
$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Text = "Export"
$exportButton.Size = New-Object System.Drawing.Size(120, 30)
$exportButton.Location = New-Object System.Drawing.Point(380, 480)
$form.Controls.Add($exportButton)

# Always on top checkbox
$topCheckBox = New-Object System.Windows.Forms.CheckBox
$topCheckBox.Text = "Keep window on top"
$topCheckBox.Checked = $true
$topCheckBox.Location = New-Object System.Drawing.Point(530, 486)
$topCheckBox.Size = New-Object System.Drawing.Size(150, 20)
$form.Controls.Add($topCheckBox)
$topCheckBox.Add_CheckedChanged({ $form.Topmost = $topCheckBox.Checked })

# Copy buttons
$copyFQDNs = New-Object System.Windows.Forms.Button
$copyFQDNs.Text = "Copy FQDNs"
$copyFQDNs.Size = New-Object System.Drawing.Size(120, 30)
$copyFQDNs.Location = New-Object System.Drawing.Point(10, 520)
$form.Controls.Add($copyFQDNs)

$copyIPs = New-Object System.Windows.Forms.Button
$copyIPs.Text = "Copy IPs"
$copyIPs.Size = New-Object System.Drawing.Size(120, 30)
$copyIPs.Location = New-Object System.Drawing.Point(140, 520)
$form.Controls.Add($copyIPs)

$script:resultsList = @()

# Resolve FQDN
$runButton.Add_Click({
    $dataGrid.Rows.Clear()
    $script:resultsList = @()
    $servers = $inputBox.Lines | Where-Object { $_.Trim() -ne "" }

    foreach ($shortName in $servers) {
        $resolved = $false
        foreach ($suffix in $dnsSuffixes) {
            $fqdnTry = "$shortName.$suffix"
            try {
                $dns = Resolve-DnsName -Name $fqdnTry -ErrorAction Stop
                $fqdn = ($dns | Where-Object {$_.QueryType -eq "A"} | Select-Object -First 1).Name
                $ips = ($dns | Where-Object {$_.QueryType -eq "A"}).IPAddress -join "; "
                $row = [PSCustomObject]@{ ServerName = $shortName; FQDN = $fqdn; 'IPAddress(es)' = $ips }
                $script:resultsList += $row
                [void]$dataGrid.Rows.Add($row.ServerName, $row.FQDN, $row.'IPAddress(es)')
                $resolved = $true
                break
            } catch {
                continue
            }
        }
        if (-not $resolved) {
            $row = [PSCustomObject]@{ ServerName = $shortName; FQDN = "Not Found"; 'IPAddress(es)' = "" }
            $script:resultsList += $row
            [void]$dataGrid.Rows.Add($row.ServerName, $row.FQDN, $row.'IPAddress(es)')
        }
    }
})

# Export functionality
$exportButton.Add_Click({
    if ($script:resultsList.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No data to export.")
        return
    }

    $type = $exportFormat.SelectedItem
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    switch ($type) {
        "CSV"  { $saveDialog.Filter = "CSV files (*.csv)|*.csv"; $ext = ".csv" }
        "TXT"  { $saveDialog.Filter = "Text files (*.txt)|*.txt"; $ext = ".txt" }
        "XLSX" { $saveDialog.Filter = "Excel files (*.xlsx)|*.xlsx"; $ext = ".xlsx" }
        "HTML" { $saveDialog.Filter = "HTML files (*.html)|*.html"; $ext = ".html" }
    }

    $saveDialog.FileName = "nslookup_results$ext"
    if ($saveDialog.ShowDialog() -eq "OK") {
        $path = $saveDialog.FileName
        switch ($type) {
            "CSV" {
                $script:resultsList | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
            }
            "TXT" {
                $script:resultsList | ForEach-Object {
                    "$($_.ServerName) | $($_.FQDN) | $($_.'IPAddress(es)')"
                } | Out-File -FilePath $path -Encoding UTF8
            }
            "HTML" {
                $html = "<html><body><table border='1'><tr><th>ServerName</th><th>FQDN</th><th>IPAddress(es)</th></tr>"
                $script:resultsList | ForEach-Object {
                    $html += "<tr><td>$($_.ServerName)</td><td>$($_.FQDN)</td><td>$($_.'IPAddress(es)')</td></tr>"
                }
                $html += "</table></body></html>"
                $html | Out-File -FilePath $path -Encoding UTF8
            }
            "XLSX" {
                try {
                    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
                        Install-Module ImportExcel -Force -Scope CurrentUser
                    }
                    Import-Module ImportExcel
                    $script:resultsList | Export-Excel -Path $path -AutoSize
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to export XLSX. Install 'ImportExcel' module.")
                }
            }
        }
        [System.Windows.Forms.MessageBox]::Show("Exported successfully.")
    }
})

# Copy FQDNs
$copyFQDNs.Add_Click({
    if ($script:resultsList.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No FQDNs to copy.")
        return
    }
    $fqdnList = $script:resultsList | Select-Object -ExpandProperty FQDN
    [System.Windows.Forms.Clipboard]::SetText($fqdnList -join "`r`n")
    [System.Windows.Forms.MessageBox]::Show("FQDNs copied to clipboard.")
})

# Copy IPs
$copyIPs.Add_Click({
    if ($script:resultsList.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No IPs to copy.")
        return
    }
    $ipList = $script:resultsList | Select-Object -ExpandProperty 'IPAddress(es)'
    [System.Windows.Forms.Clipboard]::SetText($ipList -join "`r`n")
    [System.Windows.Forms.MessageBox]::Show("IP addresses copied to clipboard.")
})

# Show form
$form.Topmost = $topCheckBox.Checked
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
