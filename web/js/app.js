/* ══════════════════════════════════════════════════════════════
   ClimapX — Main Application Controller
   ══════════════════════════════════════════════════════════════ */

const App = {
  state: {
    activeTab: 'dashboard',
    lat: CONFIG.DEFAULT_LAT,
    lng: CONFIG.DEFAULT_LNG,
    cityName: 'Delhi',
    aqi: null,
    weather: null,
    forecast: [],
    exposure: null,
    stations: [],
    riskMap: null,
    journeyMap: null,
    overlays: { aqi: false, heat: false, flood: false },
    mapCircles: [],
    mapMarkers: [],
    routeRenderers: [],
    refreshTimer: null,
    loading: false,
    theme: localStorage.getItem('ecox_theme') || 'light',
  },

  /* ─── Boot ─── */
  init() {
    this.applyTheme(this.state.theme);
    this.setupTabs();
    this.setupSettings();
    this.setupJourneyCta();
    this.setupMenuToggle();
    this.setupGlobalListeners();
    this.showLocationGate();
  },

  /* ═══════════════ THEMING ═══════════════ */
  applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    this.state.theme = theme;
    localStorage.setItem('ecox_theme', theme);
    const tog = document.getElementById('themeToggle');
    if (tog) tog.querySelector('.material-icons-round').textContent = theme === 'dark' ? 'light_mode' : 'dark_mode';
    const sw = document.getElementById('darkToggle');
    if (sw) sw.checked = theme === 'dark';
  },

  /* ═══════════════ MENU TOGGLE (mobile) ═══════════════ */
  setupMenuToggle() {
    document.getElementById('menuToggle')?.addEventListener('click', () => {
      document.getElementById('sidebar')?.classList.toggle('open');
    });
  },

  /* ═══════════════ GLOBAL LISTENERS (once, no stacking) ═══════════════ */
  setupGlobalListeners() {
    document.getElementById('alertDismiss')?.addEventListener('click', () => {
      document.getElementById('alertBanner').style.display = 'none';
    });
    document.getElementById('refreshAlerts')?.addEventListener('click', () => this.loadAlerts());
  },

  /* ═══════════════ TABS ═══════════════ */
  setupTabs() {
    document.querySelectorAll('.nav-btn, .mob-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const tab = btn.dataset.tab;
        if (tab) this.switchTab(tab);
      });
    });
  },
  switchTab(tab) {
    this.state.activeTab = tab;
    // Toggle tab pages
    document.querySelectorAll('.tab-content').forEach(p => p.classList.toggle('active', p.id === `tab-${tab}`));
    // Toggle sidebar nav active state
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
    // Toggle mobile nav active state
    document.querySelectorAll('.mob-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
    // Update topbar titles
    const titles = { dashboard: 'Dashboard', map: 'Risk Map', journey: 'Journey Planner', alerts: 'Active Alerts', settings: 'Settings' };
    const subs = { dashboard: 'Real-time climate overview', map: 'AQI, Heat & Flood overlays', journey: 'Pollution-optimized routes', alerts: 'Floods, wildfires & heatwaves', settings: 'Theme, API keys & about' };
    const titleEl = document.getElementById('pageTitle');
    const subEl = document.getElementById('pageSubtitle');
    if (titleEl) titleEl.textContent = titles[tab] || 'EcoX';
    if (subEl) subEl.textContent = subs[tab] || '';
    // Resize maps on tab switch
    if (tab === 'map') setTimeout(() => { if (this.state.riskMap) google.maps.event.trigger(this.state.riskMap, 'resize'); }, 200);
    if (tab === 'journey') setTimeout(() => { if (this.state.journeyMap) google.maps.event.trigger(this.state.journeyMap, 'resize'); }, 200);
    // Load alerts when switching to alerts tab
    if (tab === 'alerts') setTimeout(() => this.loadAlerts(), 200);
    // Close mobile sidebar
    document.getElementById('sidebar')?.classList.remove('open');
  },

  /* ═══════════════ JOURNEY CTA ═══════════════ */
  setupJourneyCta() {
    document.getElementById('journeyCta')?.addEventListener('click', () => this.switchTab('journey'));
  },

  /* ═══════════════ LOCATION GATE ═══════════════ */
  showLocationGate() {
    const gate = document.getElementById('locGate');
    const btn = document.getElementById('locGateBtn');
    const hint = document.getElementById('locGateHint');
    if (!gate || !btn) { this.requestLocation(); return; }

    // If permission was already granted (page reload), skip gate
    if (navigator.permissions) {
      navigator.permissions.query({ name: 'geolocation' }).then(result => {
        if (result.state === 'granted') {
          this.requestLocation();
        }
      });
    }

    btn.addEventListener('click', () => {
      btn.classList.add('loading');
      btn.innerHTML = '<span class="material-icons-round">hourglass_top</span> Detecting…';
      hint.textContent = 'Your location stays on your device. We never store or share it.';
      hint.classList.remove('error');
      this.requestLocation();
    });
  },

  requestLocation() {
    const gate = document.getElementById('locGate');
    const btn = document.getElementById('locGateBtn');
    const hint = document.getElementById('locGateHint');

    if (!navigator.geolocation) {
      if (hint) { hint.textContent = 'Your browser does not support geolocation.'; hint.classList.add('error'); }
      return;
    }

    navigator.geolocation.getCurrentPosition(
      pos => {
        this.state.lat = pos.coords.latitude;
        this.state.lng = pos.coords.longitude;
        // Hide gate with animation
        if (gate) gate.classList.add('hidden');
        setTimeout(() => { if (gate) gate.style.display = 'none'; }, 400);
        this.fetchAll();
        this.state.refreshTimer = setInterval(() => this.refreshData(), 300000);
      },
      (err) => {
        console.warn('Geolocation error:', err.message);
        if (btn) { btn.classList.remove('loading'); btn.innerHTML = '<span class="material-icons-round">my_location</span> Try Again'; }
        if (hint) {
          if (err.code === 1) {
            hint.textContent = 'Location access denied. Please allow it in your browser settings and try again.';
          } else if (err.code === 2) {
            hint.textContent = 'Could not determine your location. Check GPS/network and try again.';
          } else {
            hint.textContent = 'Location request timed out. Please try again.';
          }
          hint.classList.add('error');
        }
      },
      { enableHighAccuracy: true, timeout: 15000 }
    );
  },

  /* ═══════════════ DATA FETCH ═══════════════ */
  async fetchAll() {
    if (this.state.lat == null || this.state.lng == null) {
      U.toast('Waiting for location…', 'info');
      return;
    }
    this.showLoading(true);
    try {
      const [weather, aqi, stations] = await Promise.all([
        API.getWeather(this.state.lat, this.state.lng),
        API.getAQI(this.state.lat, this.state.lng),
        API.getNearbyStations(this.state.lat, this.state.lng),
      ]);
      this.state.weather = weather;
      this.state.aqi = aqi;
      this.state.stations = stations;
      if (weather) this.state.cityName = weather.cityName;
      this.state.exposure = U.exposureScore(aqi?.aqi, weather?.temp, weather?.rain);
      // Update location badge
      const locText = document.getElementById('locationText');
      if (locText) locText.textContent = this.state.cityName;
      // Update sidebar status
      const sidebarSt = document.getElementById('sidebarStatus');
      if (sidebarSt) sidebarSt.textContent = 'Live · ' + new Date().toLocaleTimeString();
      this.renderDashboard();
      this.renderCities();
      this.updateMapInfo();
      // Re-center maps on live location
      const livePos = { lat: this.state.lat, lng: this.state.lng };
      if (this.state.riskMap) { this.state.riskMap.panTo(livePos); this.state.riskMap.setZoom(12); }
      if (this.state.journeyMap) { this.state.journeyMap.panTo(livePos); this.state.journeyMap.setZoom(12); }
      U.toast('Data refreshed', 'success');
    } catch (e) {
      console.error(e);
      U.toast('Error fetching data', 'error');
    }
    this.showLoading(false);
  },
  async refreshData() { await this.fetchAll(); },
  showLoading(show) {
    this.state.loading = show;
    const icon = document.getElementById('refreshBtn')?.querySelector('.material-icons-round');
    if (icon) icon.style.animation = show ? 'spin 1s linear infinite' : 'none';
  },

  /* ═══════════════ DASHBOARD ═══════════════ */
  renderDashboard() {
    const aqi = this.state.aqi?.aqi || 0;
    const w = this.state.weather;
    const exp = this.state.exposure;

    // ── AQI Card ──
    const aqiValue = document.getElementById('aqiValue');
    const aqiCategory = document.getElementById('aqiCategory');
    const aqiArc = document.getElementById('aqiArc');
    if (aqiValue) { aqiValue.textContent = aqi; aqiValue.style.color = U.aqiColor(aqi); }
    if (aqiCategory) aqiCategory.textContent = U.aqiLabel(aqi);
    // Animate the SVG arc gauge
    if (aqiArc) {
      const circumference = 2 * Math.PI * 52;
      const pct = Math.min(aqi / 500, 1);
      aqiArc.style.stroke = U.aqiColor(aqi);
      aqiArc.style.strokeDashoffset = circumference * (1 - pct);
    }

    // ── Pollutant Pills ──
    const pillsEl = document.getElementById('pollutantPills');
    if (pillsEl && this.state.aqi) {
      const a = this.state.aqi;
      const pollutants = [
        { label: 'PM2.5', val: a.pm25 },
        { label: 'PM10', val: a.pm10 },
        { label: 'NO\u2082', val: a.no2 },
        { label: 'O\u2083', val: a.o3 },
        { label: 'SO\u2082', val: a.so2 },
        { label: 'CO', val: a.co },
      ].filter(p => p.val != null);
      pillsEl.innerHTML = pollutants.map(p =>
        `<span class="poll-pill" style="background:${U.aqiColor(p.val)}18;color:${U.aqiColor(p.val)};border:1px solid ${U.aqiColor(p.val)}30">${p.label} <b>${p.val}</b></span>`
      ).join('');
    }
    const stationEl = document.getElementById('aqiStation');
    if (stationEl && this.state.aqi) stationEl.textContent = this.state.aqi.station;

    // ── Weather Card ──
    if (w) {
      const tempVal = document.getElementById('tempValue');
      const wDesc = document.getElementById('weatherDesc');
      const humVal = document.getElementById('humidityVal');
      const windVal = document.getElementById('windVal');
      const rainVal = document.getElementById('rainVal');
      const feelsLikeEl = document.getElementById('feelsLike');
      const weatherIcon = document.getElementById('weatherIcon');
      if (tempVal) tempVal.textContent = `${w.temp.toFixed(1)}°C`;
      if (wDesc) wDesc.textContent = w.description;
      if (humVal) humVal.textContent = `${w.humidity}%`;
      if (windVal) windVal.textContent = `${w.windSpeed.toFixed(1)} m/s`;
      if (rainVal) rainVal.textContent = `${(w.rain || 0).toFixed(1)} mm`;
      if (feelsLikeEl) feelsLikeEl.textContent = `Feels like ${w.feelsLike.toFixed(1)}\u00b0C`;
      if (weatherIcon) weatherIcon.src = `https://openweathermap.org/img/wn/${w.icon}@2x.png`;
    }

    // ── Exposure Score Card ──
    if (exp) {
      const scoreVal = document.getElementById('scoreValue');
      const scoreLevel = document.getElementById('scoreLevel');
      if (scoreVal) { scoreVal.textContent = exp.total.toFixed(0); scoreVal.style.color = U.riskColor(exp.total); }
      if (scoreLevel) {
        let badgeHtml = exp.level;
        if (exp.isSafeZone) badgeHtml += ' <span class="safe-zone-badge">✅ Safe Zone</span>';
        scoreLevel.innerHTML = badgeHtml;
      }
      // Mini bars
      const pollBar = document.getElementById('pollBar');
      const heatBar = document.getElementById('heatBar');
      const floodBar = document.getElementById('floodBar');
      if (pollBar) { pollBar.style.width = `${exp.aqiScore}%`; pollBar.style.background = U.aqiColor(aqi); }
      if (heatBar) { heatBar.style.width = `${exp.heatScore}%`; }
      if (floodBar) { floodBar.style.width = `${exp.floodScore}%`; }
      // AI Advice in score card
      const aiAdvice = document.getElementById('aiAdvice');
      if (aiAdvice && exp.advice && exp.advice.length) {
        aiAdvice.innerHTML = exp.advice.map(a =>
          `<div class="ai-advice-item"><span>${a.icon}</span><span>${a.text}</span></div>`
        ).join('');
      } else if (aiAdvice) {
        aiAdvice.innerHTML = '';
      }
    }

    // ── Alert Banner ──
    const alertBanner = document.getElementById('alertBanner');
    if (alertBanner) {
      if (aqi > 300 || (w && w.temp > 42) || (w && w.rain > 50)) {
        alertBanner.style.display = 'flex';
        const title = document.getElementById('alertBannerTitle');
        const desc = document.getElementById('alertBannerDesc');
        if (aqi > 300) { if (title) title.textContent = '⚠️ Severe Air Pollution'; if (desc) desc.textContent = `AQI ${aqi} — wear N95 mask, avoid outdoor activity`; }
        else if (w && w.temp > 42) { if (title) title.textContent = '🌡️ Extreme Heatwave'; if (desc) desc.textContent = `Temperature ${w.temp.toFixed(1)}°C — stay indoors`; }
        else { if (title) title.textContent = '🌊 Flood Warning'; if (desc) desc.textContent = `Heavy rain ${w.rain.toFixed(1)} mm/h — avoid low-lying areas`; }
      } else {
        alertBanner.style.display = 'none';
      }
    }

    // ── Advisory Card (AI Preventive Advice) ──
    const advText = document.getElementById('advisoryText');
    const advChips = document.getElementById('advisoryChips');
    if (advText) {
      const tips = [];
      // Pull AI-generated advice from exposure score
      if (exp && exp.advice) {
        exp.advice.forEach(a => tips.push(`${a.icon} ${a.text}`));
      }
      // Add hazard-specific tips
      if (aqi > 200) tips.push('😷 Wear N95 mask outdoors. Limit exposure duration.');
      else if (aqi > 100) tips.push('🟡 Sensitive groups should limit outdoor activity.');
      if (w && w.temp > 40) tips.push('🌡️ Extreme heat — stay hydrated, avoid sun 11am–4pm.');
      else if (w && w.temp > 35) tips.push('☀️ High temperature. Carry water.');
      if (w && w.rain > 20) tips.push('🌧️ Heavy rain — watch for waterlogging.');
      if (w && w.windSpeed > 15) tips.push('🌬️ High winds — avoid open areas & high structures.');
      if (!tips.length) tips.push('✅ Conditions are generally safe. Enjoy your day!');
      advText.innerHTML = tips.map(t => `<p>${t}</p>`).join('');
    }
    if (advChips) {
      const chips = [];
      if (exp && exp.total > 60) chips.push('Delay Travel');
      if (aqi > 150) chips.push('N95 Mask');
      if (w && w.temp > 35) chips.push('Hydrate');
      if (w && w.rain > 5) chips.push('Umbrella');
      if (exp && exp.isSafeZone) chips.push('✅ Safe Zone');
      else chips.push('Check AQI');
      if (exp && exp.total > 70) chips.push('Stay Indoors');
      advChips.innerHTML = chips.map(c => `<span class="achip">${c}</span>`).join('');
    }

    // ── Health Tips ──
    const tipsGrid = document.getElementById('tipsGrid');
    if (tipsGrid) {
      const allTips = [
        { icon: '💧', title: 'Stay Hydrated', text: 'Drink at least 3 liters of water in hot weather.' },
        { icon: '🫁', title: 'Air Purifier', text: 'Use air purifier indoors when AQI > 200.' },
        { icon: '🏃', title: 'Best Exercise Time', text: 'Exercise during early mornings (5–7am) for cleanest air.' },
        { icon: '🧴', title: 'Sun Protection', text: 'Apply SPF 50+ sunscreen in summers.' },
        { icon: '🚶', title: 'Shaded Routes', text: 'Walk on shaded paths to reduce heat exposure.' },
        { icon: '🥗', title: 'Anti-Pollution Diet', text: 'Eat antioxidant-rich foods to fight pollution damage.' },
        { icon: '🌱', title: 'Indoor Plants', text: 'Keep Snake Plant, Areca Palm for natural air purification.' },
        { icon: '😷', title: 'N95 over Cloth', text: 'Use N95 masks, not cloth masks, for pollution protection.' },
        { icon: '🚰', title: 'Water Safety', text: 'Avoid untreated water during floods. Boil or use purifiers.' },
        { icon: '🚗', title: 'Traffic Exposure', text: 'Close car windows in traffic jams — pollution spikes 3× at signals.' },
      ];
      tipsGrid.innerHTML = allTips.map(t => `
        <div class="tip-card">
          <div class="tip-icon">${t.icon}</div>
          <div><h4>${t.title}</h4><p>${t.text}</p></div>
        </div>
      `).join('');
    }
  },

  /* ─── Cities Grid ─── */
  async renderCities() {
    const grid = document.getElementById('citiesGrid');
    if (!grid) return;
    grid.innerHTML = CONFIG.CITIES.map(c => `
      <div class="city-card" data-city="${c.name}">
        <div class="city-name">${c.name}</div>
        <div class="city-aqi" style="color:var(--text-secondary)">Loading…</div>
      </div>
    `).join('');
    // Fetch AQI for each city (sequential to avoid throttle)
    for (const city of CONFIG.CITIES) {
      try {
        const data = await API.getCityAQI(city.name);
        const card = grid.querySelector(`[data-city="${city.name}"]`);
        if (card && data) {
          const aqiVal = typeof data.aqi === 'number' ? data.aqi : parseInt(data.aqi) || 0;
          card.querySelector('.city-aqi').innerHTML = `
            <span style="color:${U.aqiColor(aqiVal)};font-weight:900;font-size:1.6rem">${aqiVal}</span>
            <div class="city-label" style="color:${U.aqiColor(aqiVal)}">${U.aqiLabel(aqiVal)}</div>
            <div class="city-bar" style="background:${U.aqiColor(aqiVal)};width:${Math.min(100, aqiVal / 5)}%"></div>
          `;
        }
      } catch (_) {}
    }
  },

  /* ═══════════════ GOOGLE MAPS ═══════════════ */
  initMaps() {
    // Use current location or India center as temp fallback for map init
    const lat = this.state.lat || 20.5937;
    const lng = this.state.lng || 78.9629;

    // Risk Map (Map tab)
    this.state.riskMap = new google.maps.Map(document.getElementById('googleMap'), {
      center: { lat, lng },
      zoom: this.state.lat ? 12 : 5,
      mapTypeControl: false,
      streetViewControl: false,
      fullscreenControl: false,
      styles: this.mapStyles(),
    });

    // Journey Map (Journey tab)
    this.state.journeyMap = new google.maps.Map(document.getElementById('journeyMap'), {
      center: { lat, lng },
      zoom: this.state.lat ? 12 : 5,
      mapTypeControl: false,
      streetViewControl: false,
      fullscreenControl: false,
      styles: this.mapStyles(),
    });

    // Overlay buttons — using IDs from HTML
    document.getElementById('toggleAqi')?.addEventListener('click', () => this.toggleOverlay('aqi'));
    document.getElementById('toggleHeat')?.addEventListener('click', () => this.toggleOverlay('heat'));
    document.getElementById('toggleFlood')?.addEventListener('click', () => this.toggleOverlay('flood'));
    document.getElementById('toggleMyLoc')?.addEventListener('click', () => {
      this.state.riskMap.panTo({ lat: this.state.lat, lng: this.state.lng });
      this.state.riskMap.setZoom(13);
    });
    document.getElementById('toggleMapType')?.addEventListener('click', () => {
      const mt = this.state.riskMap.getMapTypeId();
      this.state.riskMap.setMapTypeId(mt === 'roadmap' ? 'satellite' : 'roadmap');
    });

    // Journey planner search
    this.setupJourneySearch();

    // Render initial overlays
    this.renderMapOverlays();

    U.toast('Maps ready', 'success');
  },

  mapStyles() {
    if (this.state.theme === 'dark') {
      return [
        { elementType: 'geometry', stylers: [{ color: '#212121' }] },
        { elementType: 'labels.text.fill', stylers: [{ color: '#757575' }] },
        { elementType: 'labels.text.stroke', stylers: [{ color: '#212121' }] },
        { featureType: 'road', elementType: 'geometry', stylers: [{ color: '#424242' }] },
        { featureType: 'water', elementType: 'geometry', stylers: [{ color: '#1a237e' }] },
      ];
    }
    return [];
  },

  toggleOverlay(type) {
    this.state.overlays[type] = !this.state.overlays[type];
    // Map button IDs: toggleAqi, toggleHeat, toggleFlood
    const btnId = `toggle${type.charAt(0).toUpperCase() + type.slice(1)}`;
    const btn = document.getElementById(btnId);
    if (btn) btn.classList.toggle('active', this.state.overlays[type]);
    this.renderMapOverlays();
    this.updateLegend();
  },

  clearMapObjects() {
    this.state.mapCircles.forEach(c => c.setMap(null));
    this.state.mapMarkers.forEach(m => m.setMap(null));
    this.state.mapCircles = [];
    this.state.mapMarkers = [];
  },

  renderMapOverlays() {
    this.clearMapObjects();
    const map = this.state.riskMap;
    if (!map) return;

    // AQI overlay — station circles + labels
    if (this.state.overlays.aqi) {
      this.state.stations.forEach(s => {
        const c = new google.maps.Circle({
          map,
          center: { lat: parseFloat(s.lat), lng: parseFloat(s.lng) },
          radius: 1500,
          fillColor: U.aqiColor(s.aqi),
          fillOpacity: 0.25,
          strokeColor: U.aqiColor(s.aqi),
          strokeWeight: 1,
        });
        this.state.mapCircles.push(c);

        const m = new google.maps.Marker({
          map,
          position: { lat: parseFloat(s.lat), lng: parseFloat(s.lng) },
          title: `${s.station}\nAQI: ${s.aqi}`,
          label: { text: `${s.aqi}`, color: '#fff', fontSize: '11px', fontWeight: 'bold' },
          icon: {
            path: google.maps.SymbolPath.CIRCLE,
            scale: 16,
            fillColor: U.aqiColor(s.aqi),
            fillOpacity: 0.9,
            strokeWeight: 2,
            strokeColor: '#fff',
          },
        });
        this.state.mapMarkers.push(m);
      });
    }

    // Heat overlay — heat zones + temp marker
    if (this.state.overlays.heat) {
      const temp = this.state.weather?.temp || 25;
      const baseRadius = temp > 40 ? 3000 : temp > 35 ? 2000 : 1200;
      const heatZones = [
        { lat: this.state.lat, lng: this.state.lng, radius: baseRadius, factor: 1.0 },
        { lat: this.state.lat + 0.03, lng: this.state.lng + 0.02, radius: baseRadius * 0.7, factor: 0.9 },
        { lat: this.state.lat - 0.02, lng: this.state.lng - 0.03, radius: baseRadius * 0.8, factor: 1.1 },
      ];
      heatZones.forEach(z => {
        const t = temp * z.factor;
        const c = new google.maps.Circle({
          map,
          center: { lat: z.lat, lng: z.lng },
          radius: z.radius,
          fillColor: U.heatColor(t),
          fillOpacity: 0.2,
          strokeColor: U.heatColor(t),
          strokeWeight: 1,
        });
        this.state.mapCircles.push(c);
      });
      const m = new google.maps.Marker({
        map,
        position: { lat: this.state.lat, lng: this.state.lng },
        title: `Temperature: ${temp.toFixed(1)}°C`,
        label: { text: `🌡️${temp.toFixed(0)}°`, fontSize: '12px' },
      });
      this.state.mapMarkers.push(m);
    }

    // Flood overlay — flood risk zones
    if (this.state.overlays.flood) {
      const rain = this.state.weather?.rain || 0;
      const floodZones = [
        { lat: this.state.lat - 0.01, lng: this.state.lng, radius: rain > 20 ? 2000 : 1200 },
        { lat: this.state.lat, lng: this.state.lng + 0.015, radius: rain > 20 ? 1500 : 900 },
        { lat: this.state.lat + 0.02, lng: this.state.lng - 0.01, radius: rain > 20 ? 1200 : 700 },
      ];
      floodZones.forEach(z => {
        const c = new google.maps.Circle({
          map,
          center: { lat: z.lat, lng: z.lng },
          radius: z.radius,
          fillColor: '#2196F3',
          fillOpacity: rain > 5 ? 0.25 : 0.1,
          strokeColor: '#1565C0',
          strokeWeight: 1,
        });
        this.state.mapCircles.push(c);
      });
      if (rain > 0) {
        const m = new google.maps.Marker({
          map,
          position: { lat: this.state.lat - 0.01, lng: this.state.lng },
          title: `Rainfall: ${rain.toFixed(1)} mm/h`,
          label: { text: `🌧️${rain.toFixed(0)}mm`, fontSize: '12px' },
        });
        this.state.mapMarkers.push(m);
      }
    }

    // Safe Zone indicator — green circle at user's location when exposure < 30
    if (this.state.exposure && this.state.exposure.isSafeZone) {
      const safeCircle = new google.maps.Circle({
        map,
        center: { lat: this.state.lat, lng: this.state.lng },
        radius: 2000,
        fillColor: '#4CAF50',
        fillOpacity: 0.08,
        strokeColor: '#2E7D32',
        strokeWeight: 2,
        strokeOpacity: 0.4,
      });
      this.state.mapCircles.push(safeCircle);
      const safeMarker = new google.maps.Marker({
        map,
        position: { lat: this.state.lat, lng: this.state.lng },
        title: 'Safe Zone — Low exposure risk',
        label: { text: '✅ Safe', fontSize: '11px', fontWeight: 'bold' },
        icon: {
          path: google.maps.SymbolPath.CIRCLE,
          scale: 0,
        },
      });
      this.state.mapMarkers.push(safeMarker);
    }

    // Update bottom info and legend
    this.updateMapInfo();
    this.updateLegend();
  },

  updateLegend() {
    const lg = document.getElementById('mapLegend');
    if (!lg) return;
    const active = [];
    if (this.state.overlays.aqi) active.push(`<span class="legend-chip"><span class="material-icons-round" style="color:var(--cat-air)">air</span> AQI Stations</span>`);
    if (this.state.overlays.heat) active.push(`<span class="legend-chip"><span class="material-icons-round" style="color:var(--cat-heat)">whatshot</span> Heat Zones</span>`);
    if (this.state.overlays.flood) active.push(`<span class="legend-chip"><span class="material-icons-round" style="color:var(--cat-flood)">water</span> Flood Risk</span>`);
    if (this.state.exposure && this.state.exposure.isSafeZone) active.push(`<span class="legend-chip" style="border-color:#2E7D32"><span class="material-icons-round" style="color:#2E7D32">verified_user</span> Safe Zone</span>`);
    lg.innerHTML = active.join('');
  },

  updateMapInfo() {
    const scoreNum = document.getElementById('mapScoreNum');
    const expLabel = document.getElementById('mapExposureLabel');
    const expTip = document.getElementById('mapExposureTip');
    if (!scoreNum) return;
    const exp = this.state.exposure;
    if (exp) {
      scoreNum.textContent = exp.total.toFixed(0);
      scoreNum.style.color = U.riskColor(exp.total);
      if (expLabel) expLabel.textContent = `AI Exposure: ${exp.level}`;
      if (expTip) {
        const parts = [];
        if (this.state.aqi) parts.push(`AQI ${this.state.aqi.aqi}`);
        if (this.state.weather) parts.push(`${this.state.weather.temp.toFixed(1)}°C`);
        if (this.state.weather?.rain > 0) parts.push(`Rain ${this.state.weather.rain.toFixed(1)}mm`);
        if (exp.timeFactor) parts.push(`Time×${exp.timeFactor.toFixed(2)}`);
        expTip.textContent = parts.join(' · ') || 'No data';
      }
    }
    const infoWrap = document.getElementById('mapBottomInfo')?.querySelector('.map-info-score');
    if (infoWrap && exp) infoWrap.style.background = U.riskColor(exp.total) + '18';
  },

  /* ═══════════════ JOURNEY PLANNER ═══════════════ */
  setupJourneySearch() {
    const destInput = document.getElementById('destInput');
    const sugBox = document.getElementById('suggestions');
    const clearBtn = document.getElementById('clearDest');
    if (!destInput) return;

    let debounceTimer;
    const autocompleteService = new google.maps.places.AutocompleteService();
    const placesService = new google.maps.places.PlacesService(this.state.journeyMap);

    // Clear button
    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        destInput.value = '';
        clearBtn.style.display = 'none';
        sugBox.style.display = 'none';
        this._destination = null;
        // Reset journey UI
        document.getElementById('jTabs').style.display = 'none';
        document.getElementById('journeyEmpty').style.display = 'block';
        document.getElementById('routesList').style.display = 'none';
        this.state.routeRenderers.forEach(r => r.setMap(null));
        this.state.routeRenderers = [];
      });
    }

    destInput.addEventListener('input', () => {
      clearTimeout(debounceTimer);
      const q = destInput.value.trim();
      if (clearBtn) clearBtn.style.display = q.length > 0 ? 'block' : 'none';
      if (q.length < 3) { sugBox.innerHTML = ''; sugBox.style.display = 'none'; return; }
      debounceTimer = setTimeout(() => {
        autocompleteService.getPlacePredictions(
          { input: q, componentRestrictions: { country: 'in' }, location: new google.maps.LatLng(this.state.lat, this.state.lng), radius: 50000 },
          (predictions, status) => {
            if (status !== 'OK' || !predictions) { sugBox.style.display = 'none'; return; }
            sugBox.style.display = 'block';
            sugBox.innerHTML = predictions.slice(0, 5).map(p => `
              <div class="sug-item" data-pid="${p.place_id}">
                <span class="material-icons-round">place</span>
                <div>
                  <div class="sug-main">${p.structured_formatting?.main_text || p.description}</div>
                  <div class="sug-sub">${p.structured_formatting?.secondary_text || ''}</div>
                </div>
              </div>
            `).join('');
            sugBox.querySelectorAll('.sug-item').forEach(item => {
              item.addEventListener('click', () => {
                const placeId = item.dataset.pid;
                destInput.value = item.querySelector('.sug-main').textContent;
                sugBox.style.display = 'none';
                if (clearBtn) clearBtn.style.display = 'block';
                placesService.getDetails({ placeId, fields: ['geometry', 'name'] }, (place, st) => {
                  if (st === 'OK' && place.geometry) {
                    this._destination = {
                      lat: place.geometry.location.lat(),
                      lng: place.geometry.location.lng(),
                      name: place.name,
                    };
                    // Show journey tabs, hide empty state
                    document.getElementById('jTabs').style.display = 'flex';
                    document.getElementById('journeyEmpty').style.display = 'none';
                    this.fetchRoutes();
                  }
                });
              });
            });
          }
        );
      }, 400);
    });

    // Journey sub-tabs (Routes / Best Time)
    document.querySelectorAll('.jtab').forEach(tab => {
      tab.addEventListener('click', () => {
        const target = tab.dataset.jtab;
        document.querySelectorAll('.jtab').forEach(t => t.classList.toggle('active', t.dataset.jtab === target));
        document.querySelectorAll('.jtab-content').forEach(c => c.classList.toggle('active', c.id === `jcontent-${target}`));
        if (target === 'besttime' && this._destination) this.fetchBestTimes();
      });
    });
  },

  async fetchRoutes() {
    if (!this._destination) return;
    const routesList = document.getElementById('routesList');
    const loadingEl = document.getElementById('routesLoading');
    if (loadingEl) loadingEl.style.display = 'block';
    if (routesList) routesList.style.display = 'none';

    const origin = { lat: this.state.lat, lng: this.state.lng };
    const dest = this._destination;

    try {
      const routes = await API.getDirections(origin, dest);
      if (loadingEl) loadingEl.style.display = 'none';
      if (!routes.length) {
        if (routesList) { routesList.style.display = 'block'; routesList.innerHTML = '<div class="journey-empty"><div class="empty-icon">😕</div><h3>No Routes Found</h3><p>Try a different destination.</p></div>'; }
        return;
      }
      const scored = await API.scoreRoutes(routes, this.state.aqi?.aqi, dest.lat, dest.lng, this.state.weather);
      this._scoredRoutes = scored;

      // Clear old renderers
      this.state.routeRenderers.forEach(r => r.setMap(null));
      this.state.routeRenderers = [];

      // Draw routes on journey map
      const colors = ['#2E7D32', '#1565C0', '#E65100'];
      scored.forEach((r, i) => {
        const renderer = new google.maps.DirectionsRenderer({
          map: this.state.journeyMap,
          directions: { routes: [r._raw], request: {} },
          routeIndex: 0,
          polylineOptions: {
            strokeColor: colors[i % 3],
            strokeWeight: i === 0 ? 6 : 3,
            strokeOpacity: i === 0 ? 1 : 0.5,
          },
          suppressMarkers: i > 0,
          preserveViewport: i > 0,
        });
        this.state.routeRenderers.push(renderer);
      });

      // Render route cards
      if (routesList) {
        routesList.style.display = 'block';
        routesList.innerHTML = scored.map((r, i) => `
          <div class="route-card ${i === 0 ? 'selected' : ''}">
            <div class="route-head">
              <div class="route-icon" style="background:${colors[i % 3]}18;color:${colors[i % 3]}">
                <span class="material-icons-round">${i === 0 ? 'verified' : 'route'}</span>
              </div>
              <div class="route-meta">
                <div class="route-name">
                  ${r.summary}
                  ${i === 0 ? '<span class="safest-badge">SAFEST</span>' : ''}
                </div>
                <div class="route-dist">${r.distance} · ${r.duration}</div>
              </div>
              <div class="route-score-circle" style="border-color:${U.riskColor(r.overall)};color:${U.riskColor(r.overall)}">
                ${r.overall.toFixed(0)}
              </div>
            </div>
            <div class="route-bars">
              <div class="rbar">
                <span class="rbar-label">🌫 Pollution</span>
                <div class="rbar-track"><div class="rbar-fill" style="width:${r.pollScore}%;background:${U.aqiColor(r.maxAqi)}"></div></div>
                <span class="rbar-val">${r.pollScore.toFixed(0)}</span>
              </div>
              <div class="rbar">
                <span class="rbar-label">🌡️ Heat</span>
                <div class="rbar-track"><div class="rbar-fill" style="width:${r.heatScore}%;background:${U.heatColor(this.state.weather?.temp || 25)}"></div></div>
                <span class="rbar-val">${r.heatScore.toFixed(0)}</span>
              </div>
              <div class="rbar">
                <span class="rbar-label">🌊 Flood</span>
                <div class="rbar-track"><div class="rbar-fill" style="width:${r.floodScore}%;background:var(--cat-flood)"></div></div>
                <span class="rbar-val">${r.floodScore.toFixed(0)}</span>
              </div>
            </div>
            ${r.warnings.length ? `<div class="route-warnings">${r.warnings.map(w => `<div class="route-warn">${w}</div>`).join('')}</div>` : ''}
          </div>
        `).join('');
      }
    } catch (e) {
      console.error('Route fetch error:', e);
      if (loadingEl) loadingEl.style.display = 'none';
      const isNetwork = e.message?.includes('Failed to fetch') || e.message?.includes('NetworkError');
      const isTimeout = e.name === 'AbortError' || e.message?.includes('timeout');
      const isMaps = !window.google || !google.maps;
      let errIcon = '⚠️', errTitle = 'Route Error', errMsg = 'Something went wrong. Please try again.';
      if (isMaps) { errIcon = '🗺️'; errTitle = 'Maps Not Loaded'; errMsg = 'Google Maps failed to load. Check your internet connection and reload the page.'; }
      else if (isNetwork) { errIcon = '📡'; errTitle = 'Network Error'; errMsg = 'Could not connect to routing service. Check your internet connection.'; }
      else if (isTimeout) { errIcon = '⏱️'; errTitle = 'Request Timed Out'; errMsg = 'Route calculation took too long. Try a shorter distance or check your connection.'; }
      else if (e.message?.includes('ZERO_RESULTS')) { errIcon = '🚫'; errTitle = 'No Route Available'; errMsg = 'No driving route exists between these locations. Try different places.'; }
      else if (e.message?.includes('NOT_FOUND')) { errIcon = '📍'; errTitle = 'Location Not Found'; errMsg = 'One or both locations could not be found. Please re-enter your origin and destination.'; }
      if (routesList) { routesList.style.display = 'block'; routesList.innerHTML = `<div class="journey-empty"><div class="empty-icon">${errIcon}</div><h3>${errTitle}</h3><p>${errMsg}</p><button onclick="App.fetchRoutes()" style="margin-top:12px;padding:10px 20px;border:none;border-radius:10px;background:var(--accent);color:#fff;cursor:pointer;font-weight:600">🔄 Retry</button></div>`; }
      U.toast(errTitle + ' — ' + errMsg, 'error');
    }
  },

  async fetchBestTimes() {
    const timesContent = document.getElementById('timesContent');
    const loadingEl = document.getElementById('timesLoading');
    if (loadingEl) loadingEl.style.display = 'block';
    if (timesContent) timesContent.style.display = 'none';

    try {
      const times = await API.getDepartureTimes(this.state.lat, this.state.lng, this.state.aqi?.aqi);
      if (loadingEl) loadingEl.style.display = 'none';
      if (!times.length) {
        if (timesContent) { timesContent.style.display = 'block'; timesContent.innerHTML = '<p style="padding:16px;text-align:center;color:var(--text-secondary)">No forecast data.</p>'; }
        return;
      }

      const best = times[0];
      if (timesContent) {
        timesContent.style.display = 'block';
        timesContent.innerHTML = `
          <!-- Best Time Hero -->
          <div class="best-time-hero">
            <div class="bth-label">🏆 Best Departure Time</div>
            <div class="bth-time">${best.timeLabel}</div>
            <div class="bth-risk" style="background:${U.riskColor(best.riskScore)}18;color:${U.riskColor(best.riskScore)}">
              Risk Score: ${best.riskScore.toFixed(0)}/100
            </div>
            <div class="bth-reason">${best.reason}</div>
            <div class="bth-conditions">
              <span class="bth-cond" style="background:${U.aqiColor(best.estAqi)}18;color:${U.aqiColor(best.estAqi)}">🌫 AQI ~${best.estAqi}</span>
              <span class="bth-cond" style="background:${U.heatColor(best.temp)}18;color:${U.heatColor(best.temp)}">🌡️ ${best.temp.toFixed(0)}°C</span>
              ${best.rain > 0 ? `<span class="bth-cond" style="background:#2196F318;color:#1565C0">🌧️ ${best.rain.toFixed(1)}mm</span>` : ''}
            </div>
          </div>

          <!-- How it works -->
          <div class="how-card">
            <h4><span class="material-icons-round" style="font-size:16px">science</span> How we calculate this</h4>
            <p>We use CPCB diurnal pollution patterns, 3-hour weather forecasts, and traffic congestion data to predict the safest departure window. AQI contributes 50%, temperature 30%, and rainfall 20% to the risk score.</p>
          </div>

          <!-- All Time Slots -->
          <div class="time-section-title">📊 Next 12 Hours</div>
          ${times.slice(0, 12).map((t, i) => `
            <div class="time-slot ${i === 0 ? 'best' : ''}">
              <div class="ts-time">${t.timeLabel}</div>
              <div class="ts-bar-wrap">
                <div class="ts-bar"><div class="ts-fill" style="width:${t.riskScore}%;background:${U.riskColor(t.riskScore)}"></div></div>
                <div class="ts-reason">${t.reason}</div>
              </div>
              <div class="ts-score-circle" style="border-color:${U.riskColor(t.riskScore)};color:${U.riskColor(t.riskScore)}">
                ${t.riskScore.toFixed(0)}
              </div>
            </div>
          `).join('')}
        `;
      }
    } catch (e) {
      console.error(e);
      if (loadingEl) loadingEl.style.display = 'none';
      if (timesContent) { timesContent.style.display = 'block'; timesContent.innerHTML = '<div class="journey-empty"><div class="empty-icon">⚠️</div><h3>Error</h3><p>Could not analyze departure times.</p></div>'; }
    }
  },

  /* ═══════════════ ALERTS ═══════════════ */
  async loadAlerts() {
    const alerts = [];
    if (this.state.weather) {
      if (this.state.weather.temp > 40) alerts.push({ type: 'heatwave', severity: 'red', icon: '🌡️', title: 'Heatwave Alert', desc: `Temperature ${this.state.weather.temp.toFixed(1)}°C — avoid outdoor activity, stay hydrated.`, time: new Date().toLocaleString() });
      else if (this.state.weather.temp > 37) alerts.push({ type: 'heatwave', severity: 'orange', icon: '☀️', title: 'Heat Advisory', desc: `Temperature ${this.state.weather.temp.toFixed(1)}°C — carry water, wear light clothing.`, time: new Date().toLocaleString() });
      if (this.state.weather.rain > 30) alerts.push({ type: 'flood', severity: 'red', icon: '🌊', title: 'Flood Warning', desc: `Heavy rainfall ${this.state.weather.rain.toFixed(1)} mm/h — waterlogging expected in low-lying areas.`, time: new Date().toLocaleString() });
      else if (this.state.weather.rain > 10) alerts.push({ type: 'flood', severity: 'orange', icon: '🌧️', title: 'Rain Advisory', desc: `Moderate rainfall ${this.state.weather.rain.toFixed(1)} mm/h — carry umbrella.`, time: new Date().toLocaleString() });
    }
    if (this.state.aqi && this.state.aqi.aqi > 300) alerts.push({ type: 'pollution', severity: 'red', icon: '😷', title: 'Severe Air Pollution', desc: `AQI ${this.state.aqi.aqi} — ${U.aqiLabel(this.state.aqi.aqi)}. Wear N95 mask, limit outdoor exposure.`, time: new Date().toLocaleString() });
    else if (this.state.aqi && this.state.aqi.aqi > 200) alerts.push({ type: 'pollution', severity: 'orange', icon: '🌫️', title: 'Poor Air Quality', desc: `AQI ${this.state.aqi.aqi} — limit outdoor exercise, use air purifier.`, time: new Date().toLocaleString() });

    // ── NASA FIRMS Wildfire Detection ──
    try {
      const fires = await API.fetchWildfires(this.state.lat, this.state.lng);
      if (fires && fires.length > 0) {
        const severity = fires.length > 5 ? 'red' : 'orange';
        alerts.push({
          type: 'wildfire', severity, icon: '🔥',
          title: `${fires.length} Active Fire${fires.length > 1 ? 's' : ''} Detected`,
          desc: `${fires.length} satellite hotspot${fires.length > 1 ? 's' : ''} within ~200 km via NASA FIRMS/VIIRS. Monitor conditions closely.`,
          time: new Date().toLocaleString(),
        });
      }
    } catch (e) { console.warn('FIRMS wildfire fetch:', e.message); }

    // ── Water Quality Warning (rain + flood risk) ──
    if (this.state.weather && this.state.weather.rain > 15) {
      alerts.push({
        type: 'flood', severity: 'orange', icon: '🚰',
        title: 'Water Contamination Risk',
        desc: `Heavy rainfall may contaminate local water supply. Boil drinking water or use purifiers. Avoid contact with stagnant water.`,
        time: new Date().toLocaleString(),
      });
    }

    // ── Traffic Pollution Warning (rush hours + high AQI) ──
    const hour = new Date().getHours();
    if (this.state.aqi && this.state.aqi.aqi > 150 && ((hour >= 8 && hour <= 10) || (hour >= 17 && hour <= 20))) {
      alerts.push({
        type: 'pollution', severity: 'orange', icon: '🚗',
        title: 'Traffic Pollution Spike',
        desc: `Rush hour + high AQI (${this.state.aqi.aqi}). Traffic congestion multiplies pollution exposure 2–3×. Use AC, close windows, or delay travel.`,
        time: new Date().toLocaleString(),
      });
    }

    if (!alerts.length) alerts.push({ type: 'info', severity: 'green', icon: '✅', title: 'All Clear', desc: 'All environmental conditions are within safe limits for your area.', time: new Date().toLocaleString() });

    this._alerts = alerts;

    // Update count
    const countEl = document.getElementById('alertsCount');
    const critical = alerts.filter(a => a.severity === 'red' || a.severity === 'orange').length;
    if (countEl) { countEl.textContent = critical; countEl.style.color = critical > 0 ? '#F44336' : 'var(--primary)'; }

    // Render with default filter
    this.renderAlerts('all');

    // Setup filter chips
    document.querySelectorAll('.filter-chip').forEach(chip => {
      chip.onclick = () => {
        document.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        this.renderAlerts(chip.dataset.filter);
      };
    });

  },

  renderAlerts(filter) {
    const list = document.getElementById('alertsList');
    if (!list || !this._alerts) return;
    const filtered = filter === 'all' ? this._alerts : this._alerts.filter(a => a.type === filter);
    if (!filtered.length) {
      list.innerHTML = '<div class="empty-state"><span class="material-icons-round">verified_user</span><h3>No Matching Alerts</h3><p>No alerts match the selected filter.</p></div>';
      return;
    }
    const sevColors = { red: '#F44336', orange: '#FF9800', green: '#4CAF50' };
    const typeIcons = { heatwave: 'thermostat', flood: 'water', pollution: 'air', wildfire: 'local_fire_department', cyclone: 'storm', info: 'check_circle' };
    list.innerHTML = filtered.map(a => `
      <div class="alert-card" style="border-left-color: ${sevColors[a.severity] || '#999'}">
        <div class="alert-icon" style="font-size:2rem">${a.icon || '⚠️'}</div>
        <div class="alert-card-body">
          <div class="alert-card-title">${a.title}</div>
          <div class="alert-card-desc">${a.desc}</div>
          <div class="alert-meta">
            <span>🕐 ${a.time}</span>
            <span style="color:${sevColors[a.severity]};font-weight:700">${a.severity.toUpperCase()}</span>
          </div>
        </div>
      </div>
    `).join('');
  },

  /* ═══════════════ SETTINGS ═══════════════ */
  setupSettings() {
    // Theme toggle in topbar
    document.getElementById('themeToggle')?.addEventListener('click', () => {
      this.applyTheme(this.state.theme === 'dark' ? 'light' : 'dark');
    });
    // Dark mode switch in settings
    const darkToggle = document.getElementById('darkToggle');
    if (darkToggle) {
      darkToggle.checked = this.state.theme === 'dark';
      darkToggle.addEventListener('change', () => this.applyTheme(darkToggle.checked ? 'dark' : 'light'));
    }
    // Refresh button
    document.getElementById('refreshBtn')?.addEventListener('click', () => this.refreshData());
  },
};

/* ═══════════════ GOOGLE MAPS CALLBACK ═══════════════ */
function initMaps() {
  App.initMaps();
}

/* ═══════════════ DOM READY ═══════════════ */
document.addEventListener('DOMContentLoaded', () => App.init());
