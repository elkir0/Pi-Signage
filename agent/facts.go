package main

import (
	"net"
	"os"
	"os/exec"
	"strings"
)

// DeviceFacts is the device_facts block in the enrollment request.
type DeviceFacts struct {
	Hostname      string `json:"hostname"`
	MachineID     string `json:"machine_id"`
	Model         string `json:"model"`
	OS            string `json:"os"`
	PlayerVersion string `json:"player_version"`
	MAC           string `json:"mac"`
	LocalIP       string `json:"local_ip"`
}

func gatherFacts() DeviceFacts {
	f := DeviceFacts{
		Hostname:      readHostname(),
		MachineID:     readTrim("/etc/machine-id"),
		Model:         readTrim("/proc/device-tree/model"),
		OS:            readOSPretty(),
		PlayerVersion: strings.TrimSpace(firstNonEmpty(readTrim("/opt/pisignage/VERSION"), "0.12")),
	}
	f.MAC, f.LocalIP = primaryIface()
	return f
}

func readHostname() string {
	if h, err := os.Hostname(); err == nil {
		return h
	}
	return ""
}

func readTrim(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	// device-tree model is NUL-terminated; strip NULs and whitespace.
	return strings.TrimSpace(strings.ReplaceAll(string(b), "\x00", ""))
}

func readOSPretty() string {
	b, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(line, "PRETTY_NAME=") {
			return strings.Trim(strings.TrimPrefix(line, "PRETTY_NAME="), "\"")
		}
	}
	return ""
}

// primaryIface returns the MAC + IPv4 of the interface carrying the default
// route (best-effort via a UDP dial that sends nothing).
func primaryIface() (mac, ip string) {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err == nil {
		defer conn.Close()
		if la, ok := conn.LocalAddr().(*net.UDPAddr); ok {
			ip = la.IP.String()
		}
	}
	if ip != "" {
		if ifaces, err := net.Interfaces(); err == nil {
			for _, ifc := range ifaces {
				addrs, _ := ifc.Addrs()
				for _, a := range addrs {
					if ipn, ok := a.(*net.IPNet); ok && ipn.IP.String() == ip {
						return ifc.HardwareAddr.String(), ip
					}
				}
			}
		}
	}
	return mac, ip
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

// reachableBinaries is a tiny sanity probe used at startup so failures are
// actionable in the journal rather than surfacing mid-command.
func reachableBinaries() []string {
	var missing []string
	for _, bin := range []string{"wg", "wg-quick", "ip"} {
		if _, err := exec.LookPath(bin); err != nil {
			missing = append(missing, bin)
		}
	}
	return missing
}
