<template>
  <div class="relative inline-block" :class="iconClass">
    <svg :viewBox="getIconViewBox" :class="iconClass" xmlns="http://www.w3.org/2000/svg">
      <!-- Gradient definitions -->
      <defs v-if="useGradient && processedGradientColors.length > 1">
        <linearGradient :id="gradientId" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop
            v-for="(color, index) in processedGradientColors"
            :key="index"
            :offset="
              (() => {
                // If first color is green and there are 3+ colors, offset the second color by 15%
                if (
                  processedGradientColors.length >= 3 &&
                  index === 1 &&
                  processedGradientColors[0].toLowerCase() === 'rgb(118, 153, 78)'
                ) {
                  return `${(index / (processedGradientColors.length - 1)) * 120}%`;
                }
                return `${(index / (processedGradientColors.length - 1)) * 100}%`;
              })()
            "
            :stop-color="color"
          />
        </linearGradient>
      </defs>
      <!-- Icon path -->
      <path :d="getIconPath" :style="`fill: ${getFillColor}`" />
      <!-- Additional paths for complex icons -->
      <g v-if="getAdditionalPaths.length > 0">
        <path
          v-for="(path, index) in getAdditionalPaths"
          :key="index"
          :d="path.d"
          :style="`fill: ${path.fill || getFillColor}`"
          :stroke="path.stroke"
          :stroke-width="path.strokeWidth"
          :stroke-linecap="path.strokeLinecap"
          :stroke-linejoin="path.strokeLinejoin"
        />
      </g>

      <!-- Circle for flower center -->
      <circle
        v-if="iconName === 'famicons:flower'"
        cx="256"
        cy="256"
        r="48"
        :style="`fill: ${getFillColor}`"
      />
    </svg>
  </div>
</template>

<script setup lang="ts">
interface Props {
  iconName: string;
  iconClass?: string;
  iconStyle?: string;
  useGradient?: boolean;
  gradientColors?: string[];
  gradientId?: string;
}

const props = withDefaults(defineProps<Props>(), {
  iconClass: 'w-6 h-6',
  iconStyle: 'currentColor',
  useGradient: false,
  gradientColors: () => ['#10b981', '#059669'],
  gradientId: 'gradient',
});

interface AdditionalPath {
  d: string;
  fill?: string;
  stroke?: string;
  strokeWidth?: string;
  strokeLinecap?: 'round' | 'butt' | 'square' | 'inherit';
  strokeLinejoin?: 'round' | 'inherit' | 'miter' | 'bevel';
}

interface IconData {
  viewBox: string;
  path: string;
  additionalPaths: AdditionalPath[];
}

// Icon definitions
const iconData: Record<string, IconData> = {
  // Conifer/Evergreen tree - used for conifers (rhs_types: 19)
  'emojione-monotone:evergreen-tree': {
    viewBox: '0 0 64 64',
    path: 'm61 53.684l-12.88-8.936c4.842-.894 8.047-1.832 8.047-1.832l-10.834-9.02c3.628-.865 6.001-1.735 6.001-1.735l-9.123-9.523c2.6-.894 4.289-1.771 4.289-1.771L31.999 2L17.5 20.867s1.689.877 4.288 1.771l-9.121 9.523s2.372.87 5.999 1.734L7.833 42.916s3.205.938 8.046 1.832L3 53.684s10.053 2.456 22.233 3.209V62h13.534v-5.107C50.946 56.14 61 53.684 61 53.684',
    additionalPaths: [],
  },
  // Tree - used for trees (rhs_types: 13)
  'f7:tree': {
    viewBox: '0 0 56 56',
    path: 'M31.8 36.237q-1.376 5.14-.074 8.574c1.595 4.208 7.2 5.419 7.464 6.522S31.726 53 27.358 53c-4.367 0-9.724-.833-9.724-1.667c0-.833 5.084-1.939 6.629-6.6q1.35-4.076-.296-9.361a2.8 2.8 0 0 1-.845.128c-1.191 0-2.183-.73-2.397-1.694c-.822.54-1.852.86-2.969.86c-2.41 0-4.411-1.492-4.807-3.454a4.5 4.5 0 0 1-1.047.121C9.747 31.333 8 29.841 8 28c0-1.243.796-2.327 1.977-2.9c-.607-.379-1.001-.992-1.001-1.683q.002-.362.135-.686C8.442 22.434 8 21.92 8 21.333c0-.727.682-1.345 1.632-1.573C8.637 19.15 8 18.214 8 17.167c0-1.663 1.603-3.04 3.699-3.293a3.37 3.37 0 0 1-.772-2.124c0-2.071 1.965-3.75 4.39-3.75q.366 0 .718.05c.585-1.483 2.227-2.55 4.16-2.55c.537 0 1.051.082 1.527.233C22.052 4.179 23.646 3 25.56 3c1.958 0 3.58 1.232 3.86 2.837c.715-.716 1.78-1.17 2.97-1.17c2.155 0 3.902 1.492 3.902 3.333c0 .62-.199 1.201-.544 1.699q.266-.032.544-.032c2.006 0 3.66 1.293 3.878 2.958a4.4 4.4 0 0 1 1.975-.458c2.156 0 3.903 1.492 3.903 3.333c0 1.255-.812 2.348-2.012 2.917c1.2.568 2.012 1.661 2.012 2.916c0 1.09-.613 2.059-1.56 2.667c.366.418.584.937.584 1.5q-.001.325-.092.624c1.8.853 3.019 2.493 3.019 4.376c0 2.761-2.62 5-5.854 5a6.7 6.7 0 0 1-2.362-.424c-.886.776-2.123 1.257-3.491 1.257a5.4 5.4 0 0 1-2.955-.85c-.42.357-.948.621-1.538.754',
    additionalPaths: [],
  }, // Leaves - default for other plant types
  'icon-park-solid:leaves-two': {
    viewBox: '0 0 48 48',
    path: 'M21 17c8.385-2.12 17.665-8.76 21-12c0 15-3.801 23.472-6 26c-10 11.5-20.935 6.16-23 2c-4.855-9.777 2.07-14.5 8-16',
    additionalPaths: [
      {
        d: 'M6 43c.412-2 2.388-6.6 7-9',
        fill: 'currentColor',
        stroke: 'currentColor',
        strokeLinecap: 'round' as const,
        strokeLinejoin: 'round' as const,
        strokeWidth: '4',
      },
    ],
  },
  // Flower - used for flower overlays
  'famicons:flower': {
    viewBox: '0 0 512 512',
    path: 'M475.93 303.91a67.49 67.49 0 0 0-44.34-115.53a5.2 5.2 0 0 1-4.58-3.21a5.21 5.21 0 0 1 1-5.51A67.83 67.83 0 0 0 378 66.33h-.25A67.13 67.13 0 0 0 332.35 84a5.21 5.21 0 0 1-5.52 1a5.23 5.23 0 0 1-3.22-4.58a67.68 67.68 0 0 0-135.23 0a5.2 5.2 0 0 1-3.21 4.58a5.21 5.21 0 0 1-5.52-1a67.1 67.1 0 0 0-45.44-17.69H134a67.91 67.91 0 0 0-50 113.34a5.21 5.21 0 0 1 1 5.51a5.2 5.2 0 0 1-4.58 3.21a67.71 67.71 0 0 0 0 135.23a5.23 5.23 0 0 1 4.58 3.23a5.22 5.22 0 0 1-1 5.52a67.54 67.54 0 0 0 50.08 113h.25A67.38 67.38 0 0 0 179.65 428a5.21 5.21 0 0 1 5.51-1a5.2 5.2 0 0 1 3.21 4.58a67.71 67.71 0 0 0 135.23 0a5.23 5.23 0 0 1 3.22-4.58a5.21 5.21 0 0 1 5.51 1a67.38 67.38 0 0 0 45.29 17.42h.25a67.48 67.48 0 0 0 50.08-113a5.22 5.22 0 0 1-1-5.52a5.23 5.23 0 0 1 4.58-3.22a67.3 67.3 0 0 0 44.4-19.77M256 336a80 80 0 1 1 80-80a80.09 80.09 0 0 1-80 80',
    additionalPaths: [],
  },
  // Apple/Fruit - used for fruit overlays
  'tabler:apple-filled': {
    viewBox: '0 0 24 24',
    path: 'M15 2a1 1 0 0 1 .117 1.993L15 4c-.693 0-1.33.694-1.691 1.552a5.1 5.1 0 0 1 1.982-.544L15.556 5C18.538 5 21 8.053 21 11.32c0 3.547-.606 5.862-2.423 8.578c-1.692 2.251-4.092 2.753-6.41 1.234a.31.31 0 0 0-.317-.01c-2.335 1.528-4.735 1.027-6.46-1.27C3.607 17.184 3 14.868 3 11.32l.004-.222C3.112 7.917 5.53 5 8.444 5c.94 0 1.852.291 2.688.792C11.551 3.842 12.95 2 15 2M7.966 8.154C6.606 9.012 6 10.214 6 12a1 1 0 0 0 2 0c0-1.125.28-1.678 1.034-2.154a1 1 0 1 0-1.068-1.692',
    additionalPaths: [],
  },
  // Stem - used for stem overlays
  'game-icons:birch-trees': {
    viewBox: '0 0 512 512',
    path: 'm78.62 25.25l2.78 50.8c8.96-6.56 27.6-5.93 38 3.54L82.24 91.44l.64 11.46l26.92-1l-26.46 9.5l2.84 51.8l-70.07-43.3l-.17 47l73.52 53.5l18.34-22.1c1.6 11.1-.7 23.8-15.44 41.8c0 0 6.7 52 3.8 125.3l42.14 4l-42.54 5.5c-.4 4.5-.6 8.9-.9 13.5c52.64-15.6 63.94 9.9 63.94 9.9l-65.44 10.3c-2.2 25-5.64 51-10.71 78.1H191c0-75-6.2-122.2-9.2-170.8c-22.1 2.8-45.3-1.1-45.3-1.1s12-18 44.4-17.5c-.7-21.5-.7-44 1-69.7l-43.6-4l34.8-4.8c-4.9-33.8-10-65.3-14.7-94.4l-25.3.5l22.4-18.5c-4.9-30.45-9.1-57.73-11.6-81.15zm267.08 0c-.9 10.31-1.8 20.4-2.4 30.29c17.6-12.7 39 11.56 39 11.56s-20.5 19.36-40.2 6.77v.2c-1.3 20.97-2.2 41.93-3 62.83c-.8 19.8-1.4 39.5-2.3 59.2c-.5 11.5-1.1 22.9-1.7 34.5c14.2 5.4 28.8 10.6 43.1 15.8l-44.6 7.5c-3.1 43.5-8.3 89.2-18.3 140.9l49.2 13.8l-52.6 3.1c-4.9 22.9-10.8 47.9-17.9 75h123.1c.1-8.3.1-15.6.3-22.9l-16.8-5.2s7.1-7.3 17.1-12.5c1.1-41.8 3.5-77 6.6-106.8l-37.4-7.8l38.3-.8c.3-3.3.8-6.6 1.2-9.8c-21.3.6-43.6-9.3-43.6-9.3s18-22.8 45.7-7c12.4-88.4 30.7-115.1 30.7-115.1l-48 59.3c-.5-16.3 5.7-40.2 22.6-56.8c-3.5-15.4-4.9-33.7-5.1-52.5l-25.5-5.7l25.5-3.3c0-3.9.1-7.7.3-11.6l-42.1 4.6s16.8-26.26 42.6-18.1c2.5-42.99 9.1-80.15 9.1-80.15zM216.5 34.1l7.9 49.76l-52-37.06l7.9 21.34c81.1 51.66 107.4 86.96 136.5 125.06l1.2-47.1s-54.9-9.4-101.5-112m279.6 23.94l-45.9 24.21l-2.1 31.95l47.3-35.92zM141.2 236.3c6.1-.1 13.2 1.2 21.1 5c-12.3 18.3-45.2 4.7-45.2 4.7c7.8-6 14.4-9.4 24.1-9.7m220.4 132.1c8.8-.2 17.8 4.1 25.3 17.2c-15.6 9-29.9 8.9-40.2 6.5c-10.3-2.3-16.7-6.9-16.7-6.9s15.1-16.4 31.6-16.8m-212.3 76.4c8.1-.3 17.1 3.1 26 13.8c-23.1 11.4-53.6 1-53.6 1c9.4-7.9 15.4-14.4 27.6-14.8',
    additionalPaths: [],
  },
};

const getIconViewBox = computed(() => {
  const icon = iconData[props.iconName as keyof typeof iconData];
  return icon?.viewBox || '0 0 24 24';
});

const getIconPath = computed(() => {
  const icon = iconData[props.iconName as keyof typeof iconData];
  return icon?.path || '';
});

const getAdditionalPaths = computed(() => {
  const icon = iconData[props.iconName as keyof typeof iconData];
  return icon?.additionalPaths || [];
});

// Process gradient colors - convert RGB strings to hex if needed
const processedGradientColors = computed(() => {
  if (!props.gradientColors) return [];

  return props.gradientColors.map((color) => {
    // If color contains commas, it's RGB values like "146, 64, 14"
    if (color.includes(',')) {
      const rgbValues = color.split(',').map((val) => parseInt(val.trim()));
      return `rgb(${rgbValues.join(', ')})`;
    }
    // Otherwise, assume it's already a valid color format
    return color;
  });
});

// Determine fill color - use gradient for multiple colors, direct color for single color
const getFillColor = computed(() => {
  if (props.useGradient && processedGradientColors.value.length > 1) {
    return `url(#${props.gradientId})`;
  } else if (processedGradientColors.value.length === 1) {
    return processedGradientColors.value[0];
  } else {
    return props.iconStyle;
  }
});
</script>
