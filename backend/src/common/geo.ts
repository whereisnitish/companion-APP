const EARTH_RADIUS_KM = 6371;
const toRad = (deg: number) => (deg * Math.PI) / 180;

export interface Coordinates {
  latitude: number;
  longitude: number;
}

/** Great-circle distance. Plenty accurate for "2.4 km away". */
export function distanceKm(a: Coordinates, b: Coordinates): number {
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);

  const h =
    Math.sin(dLat / 2) ** 2 + Math.sin(dLon / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

/**
 * A latitude/longitude box that contains the radius circle.
 * Used to push a cheap pre-filter into Postgres before exact distance maths.
 */
export function boundingBox(center: Coordinates, radiusKm: number) {
  const latDelta = radiusKm / 111.32;
  const cos = Math.cos(toRad(center.latitude));
  const lonDelta = radiusKm / (111.32 * (Math.abs(cos) < 0.01 ? 0.01 : cos));
  return {
    minLat: center.latitude - latDelta,
    maxLat: center.latitude + latDelta,
    minLon: center.longitude - lonDelta,
    maxLon: center.longitude + lonDelta,
  };
}

export function roundDistance(km: number): number {
  return km < 10 ? Math.round(km * 10) / 10 : Math.round(km);
}
