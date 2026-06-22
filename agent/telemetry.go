package main

import "time"

// playerObj / systemObj mirror the heartbeat 'player' and 'system' sub-objects.
type playerObj struct {
	Online          bool    `json:"online"`
	Status          string  `json:"status"`
	ActivePlaylist  *string `json:"active_playlist"`
	ActiveSlug      *string `json:"active_slug"`
	PlaylistVersion int     `json:"playlist_version"`
	ItemIndex       int     `json:"item_index"`
	ItemCount       int     `json:"item_count"`
	CurrentItem     string  `json:"current_item"`
}

type systemObj struct {
	CPUPct          float64  `json:"cpu_pct"`
	Load1Min        float64  `json:"load_1min"`
	MemPct          float64  `json:"mem_pct"`
	DiskPct         int      `json:"disk_pct"`
	TempC           *float64 `json:"temp_c"`
	Uptime          string   `json:"uptime"`
	UnderVoltageNow bool     `json:"under_voltage_now"`
	UnderVoltageEver bool    `json:"under_voltage_ever"`
}

// heartbeat is the full hb payload (envelope + telemetry).
type heartbeat struct {
	V            int        `json:"v"`
	TS           int64      `json:"ts"`
	DeviceID     string     `json:"device_id"`
	Seq          uint64     `json:"seq"`
	UptimeS      int64      `json:"uptime_s"`
	AgentVersion string     `json:"agent_version"`
	Player       *playerObj `json:"player"`
	System       *systemObj `json:"system"`
	Degraded     []string   `json:"degraded,omitempty"`
}

// buildHeartbeat assembles a heartbeat, tolerating partial loopback failures.
func buildHeartbeat(api *LocalAPI, deviceID string, seq uint64, bootTime time.Time) heartbeat {
	hb := heartbeat{
		V:            1,
		TS:           time.Now().Unix(),
		DeviceID:     deviceID,
		Seq:          seq,
		UptimeS:      int64(time.Since(bootTime).Seconds()),
		AgentVersion: agentVersion,
	}

	if ds, err := api.displayState(); err == nil {
		hb.Player = mapPlayer(ds)
	} else {
		hb.Degraded = append(hb.Degraded, "player")
	}
	if st, err := api.stats(); err == nil {
		hb.System = mapSystem(st)
	} else {
		hb.Degraded = append(hb.Degraded, "system")
	}
	return hb
}

func mapPlayer(ds *displayStateData) *playerObj {
	p := &playerObj{Online: ds.Online, Status: "unknown"}
	if ds.State != nil {
		p.Status = orDefault(ds.State.Status, "unknown")
		p.PlaylistVersion = ds.State.Version
		p.ItemIndex = ds.State.Index
		p.ItemCount = ds.State.Count
		p.CurrentItem = ds.State.Current.Name
	}
	if ds.Active != nil {
		if ds.Active.Name != "" {
			n := ds.Active.Name
			p.ActivePlaylist = &n
		}
		if ds.Active.Slug != "" {
			s := ds.Active.Slug
			p.ActiveSlug = &s
		}
	}
	return p
}

func mapSystem(st *statsData) *systemObj {
	s := &systemObj{
		CPUPct:   st.CPU.Usage,
		Load1Min: st.CPU.Load1,
		MemPct:   st.Memory.Percent,
		DiskPct:  st.Disk.Percent,
		TempC:    st.Temperature,
		Uptime:   st.Uptime,
	}
	if st.Throttled != nil {
		s.UnderVoltageNow = st.Throttled.UnderVoltageNow
		s.UnderVoltageEver = st.Throttled.UnderVoltageOccurred
	}
	return s
}

func orDefault(s, def string) string {
	if s == "" {
		return def
	}
	return s
}
