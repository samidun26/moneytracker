import {
  createAppleSplashScreens,
  defineConfig,
  minimal2023Preset,
} from '@vite-pwa/assets-generator/config'

// Icons come from public/icon.svg (full-bleed; iOS applies its own mask).
// Splash screens use a transparent image so iOS shows a solid screen matching
// the app's grouped background — per Apple HIG, a launch screen should look like
// the first screen rather than a logo splash.
const splashDevices = [
  'iPhone 17 Pro Max',
  'iPhone 17 Pro',
  'iPhone 17',
  'iPhone Air',
  'iPhone 16 Pro Max',
  'iPhone 16 Pro',
  'iPhone 16 Plus',
  'iPhone 16',
  'iPhone 16e',
  'iPhone 13 mini',
  'iPhone 11',
  'iPhone 11 Pro Max',
  'iPhone 8',
  'iPhone 8 Plus',
] as const

const isSplash = process.env.ASSETS === 'splash'

export default defineConfig({
  headLinkOptions: { preset: '2023' },
  preset: isSplash
    ? {
        transparent: { sizes: [], favicons: [] },
        maskable: { sizes: [] },
        apple: { sizes: [] },
        appleSplashScreens: createAppleSplashScreens(
          {
            padding: 0,
            resizeOptions: { background: '#F2F2F7', fit: 'contain' },
            darkResizeOptions: { background: '#000000', fit: 'contain' },
            linkMediaOptions: { log: true, addMediaScreen: true, basePath: '/', xhtml: false },
            png: { compressionLevel: 9, quality: 60 },
          },
          [...splashDevices],
        ),
      }
    : {
        ...minimal2023Preset,
        transparent: { sizes: [64, 192, 512], favicons: [[48, 'favicon.ico']], padding: 0 },
        maskable: { sizes: [512], padding: 0 },
        apple: { sizes: [180], padding: 0 },
      },
  images: isSplash ? ['public/splash/blank.svg'] : ['public/icon.svg'],
})
