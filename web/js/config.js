/* ══════════════════════════════════════════════════════════════
   ClimapX — Config & API Keys
   ══════════════════════════════════════════════════════════════ */
const CONFIG = {
  // API Keys (editable from Settings tab)
  GOOGLE_MAPS_KEY: localStorage.getItem('ecox_gmap') || 'AIzaSyCrTsOTHbwYVf4_MYVAkr8ERoB86-HJMB8',
  OPENWEATHER_KEY: localStorage.getItem('ecox_owm')  || '1c5ad5920292635f331911560b2196f9',
  AQICN_KEY:       localStorage.getItem('ecox_aqicn') || '959ef43e53aa00f51bc2bcb7595351ff855f8574',
  NASA_FIRMS_KEY:  localStorage.getItem('ecox_nasa')  || 'ff13d3dc42f3423551e563d03c2b525c',

  // API Endpoints
  OWM_BASE:     'https://api.openweathermap.org/data/2.5',
  AQICN_BASE:   'https://api.waqi.info',
  FIRMS_BASE:   'https://firms.modaps.eosdis.nasa.gov/api/area/csv',

  // Defaults (null = wait for live location)
  DEFAULT_LAT: null,
  DEFAULT_LNG: null,
  REFRESH_INTERVAL: 300000, // 5 min

  // India AQI thresholds
  AQI: { GOOD: 50, SATISFACTORY: 100, MODERATE: 200, POOR: 300, VERY_POOR: 400, SEVERE: 500 },
  HEAT: { CAUTION: 35, WARNING: 40, DANGER: 45, EXTREME: 48 },

  // Major Indian cities
  CITIES: [
    { name: 'Delhi',     lat: 28.6139, lng: 77.2090 },
    { name: 'Mumbai',    lat: 19.0760, lng: 72.8777 },
    { name: 'Bangalore', lat: 12.9716, lng: 77.5946 },
    { name: 'Chennai',   lat: 13.0827, lng: 80.2707 },
    { name: 'Kolkata',   lat: 22.5726, lng: 88.3639 },
    { name: 'Hyderabad', lat: 17.3850, lng: 78.4867 },
    { name: 'Pune',      lat: 18.5204, lng: 73.8567 },
    { name: 'Patna',     lat: 25.6093, lng: 85.1376 },
    { name: 'Lucknow',   lat: 26.8467, lng: 80.9462 },
    { name: 'Noida',     lat: 28.5355, lng: 77.3910 },
  ],

  // Exposure weights
  WEIGHTS: { aqi: 0.35, heat: 0.25, flood: 0.20, fire: 0.10, water: 0.10 },

  // CPCB hourly AQI factors
  HOURLY_AQI: {0:1.15,1:1.20,2:1.20,3:1.15,4:1.05,5:0.85,6:0.75,7:0.70,8:0.80,9:0.90,10:1.00,11:0.95,12:0.90,13:0.85,14:0.85,15:0.90,16:0.95,17:1.05,18:1.10,19:1.15,20:1.15,21:1.15,22:1.15,23:1.15},
};
