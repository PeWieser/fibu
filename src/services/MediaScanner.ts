import * as MediaLibrary from 'expo-media-library';

export type Asset = Awaited<ReturnType<typeof MediaLibrary.getAssetsAsync>>['assets'][0];

export async function requestPermissions(): Promise<boolean> {
  const { status } = await MediaLibrary.requestPermissionsAsync();
  return status === 'granted';
}

export async function scanAlbum(
  albumId: string,
  mediaType: 'PHOTOS' | 'VIDEOS' | 'BOTH'
): Promise<Asset[]> {
  const assets: Asset[] = [];
  let hasNextPage = true;
  let after: string | undefined = undefined;

  const typeMap = {
    PHOTOS: ['photo'],
    VIDEOS: ['video'],
    BOTH: ['photo', 'video'],
  } as const;

  while (hasNextPage) {
    const page = await MediaLibrary.getAssetsAsync({
      album: albumId,
      // @ts-expect-error - expo-media-library type definition expects array of string literals
      mediaType: typeMap[mediaType],
      first: 200,
      after,
    });

    assets.push(...page.assets);
    hasNextPage = page.hasNextPage;
    after = page.endCursor;
  }

  return assets;
}

export function getAssetUri(asset: Asset): string {
  return asset.uri;
}
