/* ══════════════════════════════════════════════════════════════
   ClimapX — API Services (Weather, AQI, Routing, Forecast)
   ══════════════════════════════════════════════════════════════ */

const API = {
  // ─── Fetch with timeout ───
  async _fetch(url, timeout = 10000) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeout);
    try {
      const res = await fetch(url, { signal: ctrl.signal });
      clearTimeout(timer);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json();
    } catch (e) {
      clearTimeout(timer);
      console.warn('Fetch failed:', url.substring(0, 80), e.message);
      return null;
    }
  },

  // ═══════════════ WEATHER ═══════════════
  async getWeather(lat, lng) {
    const data = await this._fetch(
      `${CONFIG.OWM_BASE}/weather?lat=${lat}&lon=${lng}&appid=${CONFIG.OPENWEATHER_KEY}&units=metric`
    );
    if (!data || !data.main) return null;
    const rain = data.rain ? (data.rain['1h'] || data.rain['3h'] || 0) : 0;
    return {
      temp: data.main.temp,
      feelsLike: data.main.feels_like,
      humidity: data.main.humidity,
      windSpeed: data.wind?.speed || 0,
      description: data.weather?.[0]?.description || 'N/A',
      icon: data.weather?.[0]?.icon || '01d',
      rain,
      pressure: data.main.pressure,
      visibility: data.visibility || 10000,
      cityName: data.name || 'Unknown',
    };
  },

  async getForecast(lat, lng) {
    const data = await this._fetch(
      `${CONFIG.OWM_BASE}/forecast?lat=${lat}&lon=${lng}&appid=${CONFIG.OPENWEATHER_KEY}&units=metric`
    );
    if (!data || !data.list) return [];
    return data.list.map(item => ({
      dt: item.dt * 1000,
      temp: item.main.temp,
      rain: item.rain ? (item.rain['1h'] || item.rain['3h'] || 0) : 0,
      wind: item.wind?.speed || 0,
      description: item.weather?.[0]?.description || '',
    }));
  },

  // ═══════════════ AIR QUALITY ═══════════════
  async getAQI(lat, lng) {
    const data = await this._fetch(
      `${CONFIG.AQICN_BASE}/feed/geo:${lat};${lng}/?token=${CONFIG.AQICN_KEY}`
    );
    if (!data || data.status !== 'ok') return null;
    const d = data.data;
    return {
      aqi: d.aqi || 0,
      station: d.city?.name || 'Unknown',
      lat: d.city?.geo?.[0] || lat,
      lng: d.city?.geo?.[1] || lng,
      pm25: d.iaqi?.pm25?.v,
      pm10: d.iaqi?.pm10?.v,
      no2: d.iaqi?.no2?.v,
      o3: d.iaqi?.o3?.v,
      so2: d.iaqi?.so2?.v,
      co: d.iaqi?.co?.v,
      time: d.time?.s,
    };
  },

  async getCityAQI(cityName) {
    const data = await this._fetch(
      `${CONFIG.AQICN_BASE}/feed/${cityName}/?token=${CONFIG.AQICN_KEY}`
    );
    if (!data || data.status !== 'ok') return null;
    return { aqi: data.data?.aqi || 0, station: data.data?.city?.name || cityName };
  },

  async getNearbyStations(lat, lng) {
    const data = await this._fetch(
      `${CONFIG.AQICN_BASE}/map/bounds/?latlng=${lat-0.3},${lng-0.3},${lat+0.3},${lng+0.3}&token=${CONFIG.AQICN_KEY}`
    );
    if (!data || data.status !== 'ok') return [];
    return (data.data || []).slice(0, 15).map(s => ({
      aqi: parseInt(s.aqi) || 0,
      station: s.station?.name || 'Station',
      lat: s.lat,
      lng: s.lon,
    }));
  },

  // ═══════════════ DIRECTIONS ═══════════════
  async getDirections(origin, destination, mode = 'driving') {
    return new Promise((resolve, reject) => {
      if (!window.google || !google.maps) { reject(new Error('Google Maps not loaded')); return; }
      const ds = new google.maps.DirectionsService();
      ds.route({
        origin: new google.maps.LatLng(origin.lat, origin.lng),
        destination: new google.maps.LatLng(destination.lat, destination.lng),
        travelMode: google.maps.TravelMode[mode.toUpperCase()] || google.maps.TravelMode.DRIVING,
        provideRouteAlternatives: true,
      }, (result, status) => {
        if (status === 'ZERO_RESULTS') { resolve([]); return; }
        if (status !== 'OK' || !result.routes) { reject(new Error(status || 'Directions request failed')); return; }
        resolve(result.routes.map(r => {
          const leg = r.legs[0];
          return {
            summary: r.summary || 'Route',
            distance: leg.distance?.text || 'N/A',
            duration: leg.duration?.text || 'N/A',
            durationSec: leg.duration?.value || 0,
            path: r.overview_path.map(p => ({ lat: p.lat(), lng: p.lng() })),
            steps: leg.steps.map(s => ({
              instruction: s.instructions?.replace(/<[^>]*>/g, '') || '',
              distance: s.distance?.text || '',
              duration: s.duration?.text || '',
            })),
            _raw: r, // keep for DirectionsRenderer
          };
        }));
      });
    });
  },

  // ═══════════════ ROUTE SCORING ═══════════════
  async scoreRoutes(routes, originAqi, destLat, destLng, weather) {
    // Fetch destination AQI (one call only)
    let destAqi = originAqi;
    try {
      const dAqi = await this.getAQI(destLat, destLng);
      if (dAqi) destAqi = dAqi.aqi;
    } catch (_) {}

    return routes.map((route, idx) => {
      const oAqi = originAqi || 100;
      const dAqi = destAqi || oAqi;
      // Interpolate AQI at 5 sample points
      const n = 5;
      const riskPoints = [];
      for (let i = 0; i < n; i++) {
        const t = n <= 1 ? 0 : i / (n - 1);
        let aqi = Math.round(oAqi + (dAqi - oAqi) * t);
        if (i === 2 && route.durationSec > 1800) aqi = Math.round(aqi * 1.08);
        riskPoints.push(aqi);
      }
      const avgAqi = riskPoints.reduce((a, b) => a + b, 0) / n;
      const maxAqi = Math.max(...riskPoints);
      const pollScore = Math.min(100, Math.max(0, (avgAqi / 500) * 100));
      const temp = weather?.temp || 25;
      const heatScore = temp < 30 ? 0 : Math.min(100, ((temp - 30) / 20) * 100);
      const rain = weather?.rain || 0;
      const floodScore = Math.min(100, (rain / 100) * 100);
      const durPenalty = Math.min(0.15, route.durationSec / 7200);
      const overall = Math.min(100, pollScore * 0.50 + heatScore * 0.25 + floodScore * 0.25 + durPenalty * 100 * 0.10);

      const warnings = [];
      if (maxAqi > 300) warnings.push(`⚠️ Severe pollution expected (AQI ~${maxAqi})`);
      else if (maxAqi > 200) warnings.push(`😷 High pollution along route (AQI ~${maxAqi})`);
      if (temp > 40) warnings.push(`🌡️ Extreme heat (${temp.toFixed(0)}°C). Use AC transport.`);
      if (rain > 30) warnings.push(`🌧️ Heavy rain — waterlogging possible.`);
      if (route.durationSec > 3600 && avgAqi > 150) warnings.push(`⏱️ Long exposure in polluted air. Wear mask.`);

      return { ...route, pollScore, heatScore, floodScore, overall, warnings, riskPoints, maxAqi };
    }).sort((a, b) => a.overall - b.overall);
  },

  // ═══════════════ DEPARTURE TIMES ═══════════════
  async getDepartureTimes(lat, lng, currentAqi) {
    const forecast = await this.getForecast(lat, lng);
    const now = new Date();
    const currentHour = now.getHours();
    const recs = [];
    for (let h = 0; h < 24; h++) {
      const targetHour = (currentHour + h) % 24;
      const targetTime = new Date(now.getTime() + h * 3600000);
      // Find nearest forecast
      let nearest = null, closestDiff = Infinity;
      for (const f of forecast) {
        const diff = Math.abs(f.dt - targetTime.getTime());
        if (diff < closestDiff) { closestDiff = diff; nearest = f; }
      }
      const temp = nearest?.temp || 25;
      const rain = nearest?.rain || 0;
      const wind = nearest?.wind || 0;
      const baseAqi = currentAqi || 150;
      const factor = CONFIG.HOURLY_AQI[targetHour] || 1.0;
      const rainRed = rain > 5 ? 0.6 : rain > 1 ? 0.8 : 1.0;
      const windRed = wind > 5 ? 0.85 : 1.0;
      const estAqi = Math.round(baseAqi * factor * rainRed * windRed);
      const aqiRisk = Math.min(100, (estAqi / 500) * 100);
      const heatRisk = temp < 30 ? 0 : Math.min(100, ((temp - 30) / 20) * 100);
      const rainRisk = Math.min(100, (rain / 50) * 100);
      const riskScore = aqiRisk * 0.50 + heatRisk * 0.30 + rainRisk * 0.20;
      let reason;
      if (riskScore < 25) {
        if (targetHour >= 5 && targetHour <= 8) reason = '🌅 Early morning — cleanest air, cooler temperature.';
        else if (targetHour >= 13 && targetHour <= 15) reason = '☀️ Good atmospheric mixing disperses pollutants.';
        else if (rain > 5) reason = '🌧️ Rain washing pollutants. Air will be cleaner.';
        else reason = '✅ Low overall risk. Good conditions.';
      } else if (riskScore < 50) {
        if ((targetHour >= 9 && targetHour <= 10) || (targetHour >= 17 && targetHour <= 19)) reason = '🚗 Rush hour — traffic emissions spike.';
        else if (temp > 35) reason = `🌡️ High temperature (${temp.toFixed(0)}°C). Stay hydrated.`;
        else reason = '⚠️ Moderate risk. Carry water and mask.';
      } else {
        if (targetHour >= 22 || targetHour <= 3) reason = '🌙 Night inversion traps pollutants.';
        else if (temp > 40) reason = '🔥 Extreme heat + pollution.';
        else if (estAqi > 300) reason = `😷 AQI ~${estAqi}. Delay travel.`;
        else reason = '🚫 High risk. Delay non-essential travel.';
      }
      const hLabel = targetHour === 0 ? '12:00 AM' : targetHour < 12 ? `${targetHour}:00 AM` : targetHour === 12 ? '12:00 PM' : `${targetHour-12}:00 PM`;
      recs.push({ hour: targetHour, timeLabel: hLabel, riskScore, reason, estAqi, temp, rain });
    }
    recs.sort((a, b) => a.riskScore - b.riskScore);
    return recs;
  },

  // ═══════════════ NASA FIRMS WILDFIRES ═══════════════
  async fetchWildfires(lat, lng, days = 1) {
    const west = (lng - 2).toFixed(2);
    const south = (lat - 2).toFixed(2);
    const east = (lng + 2).toFixed(2);
    const north = (lat + 2).toFixed(2);
    const url = `${CONFIG.FIRMS_BASE}/${CONFIG.NASA_KEY}/VIIRS_SNPP_NRT/${west},${south},${east},${north}/${days}`;
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 12000);
      const res = await fetch(url, { signal: ctrl.signal });
      clearTimeout(timer);
      if (!res.ok) return [];
      const csv = await res.text();
      const lines = csv.trim().split('\n');
      if (lines.length < 2) return [];
      const headers = lines[0].split(',');
      const latIdx = headers.indexOf('latitude');
      const lngIdx = headers.indexOf('longitude');
      const confIdx = headers.indexOf('confidence');
      const brightIdx = headers.indexOf('bright_ti4');
      return lines.slice(1).map(line => {
        const cols = line.split(',');
        return {
          lat: parseFloat(cols[latIdx]),
          lng: parseFloat(cols[lngIdx]),
          confidence: cols[confIdx] || 'nominal',
          brightness: parseFloat(cols[brightIdx]) || 0,
        };
      }).filter(f => !isNaN(f.lat) && !isNaN(f.lng));
    } catch (e) {
      console.warn('FIRMS fetch error:', e.message);
      return [];
    }
  },
};

/* ═══════════════ UTILITY ═══════════════ */
const U = {
  aqiColor(aqi) {
    if (aqi <= 50) return '#4CAF50';
    if (aqi <= 100) return '#8BC34A';
    if (aqi <= 200) return '#FFC107';
    if (aqi <= 300) return '#FF9800';
    if (aqi <= 400) return '#F44336';
    return '#880E4F';
  },
  aqiLabel(aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Satisfactory';
    if (aqi <= 200) return 'Moderate';
    if (aqi <= 300) return 'Poor';
    if (aqi <= 400) return 'Very Poor';
    return 'Severe';
  },
  heatColor(temp) {
    if (temp < 35) return '#4CAF50';
    if (temp < 40) return '#FFC107';
    if (temp < 45) return '#FF9800';
    return '#880E4F';
  },
  riskColor(score) {
    if (score < 25) return '#4CAF50';
    if (score < 50) return '#FFC107';
    if (score < 75) return '#FF9800';
    return '#880E4F';
  },
  exposureScore(aqi, temp, rain) {
    const hour = new Date().getHours();
    const aqiScore = Math.min(100, ((aqi || 0) / 500) * 100);
    const heatScore = temp < 30 ? 0 : Math.min(100, ((temp - 30) / 20) * 100);
    const floodScore = Math.min(100, ((rain || 0) / 100) * 100);

    // Time-of-day factor (CPCB diurnal pattern)
    const timeFactor = CONFIG.HOURLY_AQI[hour] || 1.0;
    const adjustedAqi = aqiScore * timeFactor;

    // AI-weighted total: pollution 45%, heat 25%, flood 15%, time-risk 15%
    const timeRisk = timeFactor > 1.05 ? Math.min(100, (timeFactor - 0.7) * 200) : 0;
    const total = Math.min(100, adjustedAqi * 0.45 + heatScore * 0.25 + floodScore * 0.15 + timeRisk * 0.15);

    let level;
    if (total < 20) level = 'Safe';
    else if (total < 40) level = 'Low Risk';
    else if (total < 60) level = 'Moderate';
    else if (total < 80) level = 'Risky';
    else level = 'Dangerous';

    // Safe zone flag
    const isSafeZone = total < 30;

    // AI preventive advice
    const advice = [];
    if (total > 60 && (hour >= 9 && hour <= 11 || hour >= 17 && hour <= 20)) {
      advice.push({ icon: '⏰', text: 'Delay travel by 1–2 hours for safer conditions.' });
    }
    if (aqi > 200 && hour >= 10 && hour < 16) {
      advice.push({ icon: '📅', text: 'Reschedule outdoor plans to early morning (5–7 AM).' });
    }
    if (temp > 40) {
      advice.push({ icon: '🏠', text: 'Relocate to air-conditioned indoor space.' });
    }
    if (rain > 30) {
      advice.push({ icon: '🚧', text: 'Avoid low-lying areas, move to higher ground.' });
    }
    if (total < 25) {
      advice.push({ icon: '✅', text: 'Conditions safe for outdoor activity. Enjoy!' });
    } else if (total < 50 && advice.length === 0) {
      advice.push({ icon: '🛡️', text: 'Carry water and mask as precaution.' });
    }

    return { total, level, aqiScore: adjustedAqi, heatScore, floodScore, timeRisk, isSafeZone, advice, timeFactor };
  },
  toast(msg, type = 'info') {
    const c = document.getElementById('toastContainer');
    const t = document.createElement('div');
    t.className = `toast ${type}`;
    const icons = { success: 'check_circle', error: 'error', info: 'info' };
    t.innerHTML = `<span class="material-icons-round">${icons[type] || 'info'}</span>${msg}`;
    c.appendChild(t);
    setTimeout(() => { t.style.opacity = '0'; setTimeout(() => t.remove(), 300); }, 4000);
  },
};
