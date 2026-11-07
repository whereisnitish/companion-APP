import { prisma } from '../../database/prisma';
import { AppError, notFound } from '../../common/errors';

/** The app shrinks photos before sending; this only stops abuse and odd originals. */
export const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
export const ACCEPTED_PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

/**
 * Trusts the file's own bytes rather than the header the client claims, so what
 * gets served back is always one of the image types above.
 */
function detectImageType(data: Buffer): string | null {
  if (data.length >= 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    data.length >= 8 &&
    data.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  ) {
    return 'image/png';
  }
  if (
    data.length >= 12 &&
    data.toString('latin1', 0, 4) === 'RIFF' &&
    data.toString('latin1', 8, 12) === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}

/**
 * Stores a photo and returns its id. It only becomes the person's picture when
 * their profile is saved, so the one in use is kept alongside it. Anything older
 * is removed, which leaves at most two photos per person.
 */
export async function savePhoto(userId: string, data: Buffer): Promise<string> {
  const contentType = detectImageType(data);
  if (!contentType) {
    throw new AppError(415, 'UNSUPPORTED_IMAGE', 'Please use a JPEG, PNG or WebP photo.');
  }

  const photo = await prisma.profilePhoto.create({
    data: { userId, contentType, data: Uint8Array.from(data) },
    select: { id: true },
  });

  const profile = await prisma.profile.findUnique({
    where: { userId },
    select: { avatarUrl: true },
  });
  const currentId = profile?.avatarUrl?.match(/\/media\/photos\/([^/?#]+)$/)?.[1];

  await prisma.profilePhoto.deleteMany({
    where: { userId, id: { notIn: currentId ? [photo.id, currentId] : [photo.id] } },
  });

  return photo.id;
}

export async function getPhoto(id: string): Promise<{ contentType: string; data: Buffer }> {
  const photo = await prisma.profilePhoto.findUnique({
    where: { id },
    select: { contentType: true, data: true },
  });
  if (!photo) throw notFound('Photo');
  return { contentType: photo.contentType, data: Buffer.from(photo.data) };
}
