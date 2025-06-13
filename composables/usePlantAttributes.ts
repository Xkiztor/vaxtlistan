import { computed, type ComputedRef, type Ref } from 'vue';
import {
  SUNLIGHT_LABELS,
  SOIL_TYPE_LABELS,
  FULL_HEIGHT_TIME_LABELS,
  MOISTURE_LABELS,
  PH_LABELS,
  EXPOSURE_LABELS,
  SEASON_OF_INTEREST_LABELS,
  COLORS_LABELS,
  type Facit
} from '~/types/supabase-tables.d';

export const usePlantAttributes = (plant: ComputedRef<Facit | null> | Ref<Facit | null>) => {
  const sunlightLabels = computed(() => {
    if (!plant.value?.sunlight?.length) return null;
    return plant.value.sunlight
      .map((value: number) => SUNLIGHT_LABELS[value as keyof typeof SUNLIGHT_LABELS])
      .filter(label => label && label !== '---')
      .join(' / ');
  });

  const soilTypeLabels = computed(() => {
    if (!plant.value?.soil_type?.length) return null;
    return plant.value.soil_type
      .map((value: number) => SOIL_TYPE_LABELS[value as keyof typeof SOIL_TYPE_LABELS])
      .filter(label => label && label !== '---')
      .join(', ');
  });

  const fullHeightTimeLabels = computed(() => {
    if (!plant.value?.full_height_time?.length) return null;
    return plant.value.full_height_time
      .map((value: number) => FULL_HEIGHT_TIME_LABELS[value as keyof typeof FULL_HEIGHT_TIME_LABELS])
      .filter(label => label && label !== '---')
      .join(', ');
  });

  const moistureLabels = computed(() => {
    if (!plant.value?.moisture?.length) return null;
    return plant.value.moisture
      .map((value: number) => MOISTURE_LABELS[value as keyof typeof MOISTURE_LABELS])
      .filter(label => label && label !== '---')
      .join(' / ');
  });

  const phLabels = computed(() => {
    if (!plant.value?.ph?.length) return null;
    return plant.value.ph
      .map((value: number) => PH_LABELS[value as keyof typeof PH_LABELS])
      .filter(label => label && label !== '---')
      .join(' / ');
  });

  const exposureLabels = computed(() => {
    if (!plant.value?.exposure?.length) return null;
    return plant.value.exposure
      .map((value: number) => EXPOSURE_LABELS[value as keyof typeof EXPOSURE_LABELS])
      .filter(label => label && label !== '---')
      .join(' / ');
  });

  const seasonOfInterestLabels = computed(() => {
    if (!plant.value?.season_of_interest?.length) return null;
    return plant.value.season_of_interest
      .map((value: number) => SEASON_OF_INTEREST_LABELS[value as keyof typeof SEASON_OF_INTEREST_LABELS])
      .filter(label => label !== undefined)
      .join(', ');
  });
  // Get RHS type labels from plant
  const rhsTypeLabels = computed(() => {
    if (!plant.value?.rhs_types?.length) return null;
    
    const RHS_TYPE_LABELS = {
      1: "Perenn",
      2: "Klätterväxt", 
      3: "Säsongsväxt",
      4: "Lökar",
      5: "Ormbunke",
      6: "Buske",
      8: "Alpin/Stenparti",
      9: "Ros",
      10: "Gräslik",
      11: "Växthus",
      12: "Ätbar växt",
      13: "Träd",
      17: "Bambu",
      18: "Våtmark",
      19: "Barrträd"
    } as const;
    
    return plant.value.rhs_types
      .map(type => RHS_TYPE_LABELS[type as keyof typeof RHS_TYPE_LABELS])
      .filter(label => label)
      .join(', ');
  });
  // Decompress color strings and organize by season for timeline display
  const colorsBySeason = computed(() => {
    if (!plant.value?.colors?.length) return null;
      const seasons = {
      1: { name: 'Vår', items: [] as Array<{ color: string; colorId: number; attributeType: number; attributeName: string; icon: string }> },
      2: { name: 'Sommar', items: [] as Array<{ color: string; colorId: number; attributeType: number; attributeName: string; icon: string }> },
      3: { name: 'Höst', items: [] as Array<{ color: string; colorId: number; attributeType: number; attributeName: string; icon: string }> },
      4: { name: 'Vinter', items: [] as Array<{ color: string; colorId: number; attributeType: number; attributeName: string; icon: string }> }
    };// Attribute type mappings for plant parts
    const attributeTypeMap = {
      1: { name: 'Bladverket', icon: 'game-icons:three-leaves' }, // Foliage
      2: { name: 'Stam', icon: 'game-icons:birch-trees' }, // Stem  
      3: { name: 'Frukt', icon: 'tabler:apple-filled' }, // Fruit
      4: { name: 'Blomma', icon: 'famicons:flower' } // Flower
    };

    // Decompress each color string (format: "colour-season-attributeType")
    plant.value.colors.forEach((colorStr: string) => {
      const parts = colorStr.split('-');
      if (parts.length === 3) {
        const colorId = parseInt(parts[0]);
        const season = parseInt(parts[1]);
        const attributeType = parseInt(parts[2]);
        
        const colorName = COLORS_LABELS[colorId as keyof typeof COLORS_LABELS];
        const attributeInfo = attributeTypeMap[attributeType as keyof typeof attributeTypeMap];
        
        if (colorName && attributeInfo && seasons[season as keyof typeof seasons]) {          seasons[season as keyof typeof seasons].items.push({
            color: colorName,
            colorId,
            attributeType,
            attributeName: attributeInfo.name,
            icon: attributeInfo.icon
          });
        }
      }
    });

    return seasons;
  });
  // Get color CSS class for icons
  const getColorClass = (colorId: number) => {
    const colorClasses = {
      1: 'text-black', // Black
      2: 'text-blue-500', // Blue
      3: 'text-amber-600', // Bronze
      4: 'text-amber-800', // Brown
      5: 'text-yellow-200', // Cream
      6: 'text-green-500', // Green
      7: 'text-gray-500', // Grey
      8: 'text-orange-500', // Orange
      9: 'text-pink-400', // Pink
      10: 'text-purple-500', // Purple
      11: 'text-red-500', // Red
      12: 'text-gray-300', // Silver
      13: 'text-green-400', // Variegated (using green as base)
      14: 'text-gray-100', // White
      15: 'text-yellow-400', // Yellow
      16: 'text-yellow-500' // Gold
    };
    
    return colorClasses[colorId as keyof typeof colorClasses] || 'text-gray-400';
  };

  // Get RGB color values for gradient creation
  const getColorRGB = (colorId: number) => {
    const colorRGB = {
      1: '0, 0, 0', // Black
      2: '59, 130, 246', // Blue
      3: '217, 119, 6', // Bronze  
      4: '176, 87, 33', // Brown
      5: '254, 240, 138', // Cream
      6: '118, 153, 78', // Green
      // 6: '34, 170, 94', // Green
      7: '127, 144, 148', // Grey
      8: '255, 183, 79', // Orange
      9: '244, 114, 182', // Pink
      10: '168, 85, 247', // Purple
      11: '232, 44, 44', // Red
      12: '219, 223, 229', // Silver
      13: '74, 222, 128', // Variegated
      14: '243, 244, 246', // White
      15: '255, 204, 21', // Yellow
      16: '234, 179, 8' // Gold
    };
    
    return colorRGB[colorId as keyof typeof colorRGB] || '156, 163, 175';
  };

  // Get base plant icon based on rhs_types
  const getBaseIcon = computed(() => {
    if (!plant.value?.rhs_types?.length) return 'icon-park-solid:leaves-two';
    
    const rhsTypes = plant.value.rhs_types;
    
    // Check for conifers (ID: 19)
    if (rhsTypes.includes(19)) {
      return 'emojione-monotone:evergreen-tree';
    }
    
    // Check for trees (ID: 13)
    if (rhsTypes.includes(13)) {
      return 'f7:tree';
    }
    
    // Default to leaves for all other types
    return 'icon-park-solid:leaves-two';
  });

  // Create graphical plant representation by season
  const graphicalPlantBySeason = computed(() => {
    if (!plant.value?.colors?.length) return null;

    const seasons = {
      1: { name: 'Vår', plant: { foliage: [], stem: [], fruit: [], flower: [] } },
      2: { name: 'Sommar', plant: { foliage: [], stem: [], fruit: [], flower: [] } },
      3: { name: 'Höst', plant: { foliage: [], stem: [], fruit: [], flower: [] } },
      4: { name: 'Vinter', plant: { foliage: [], stem: [], fruit: [], flower: [] } }
    } as any;

    // Organize colors by season and plant part
    plant.value.colors.forEach((colorStr: string) => {
      const parts = colorStr.split('-');
      if (parts.length === 3) {
        const colorId = parseInt(parts[0]);
        const season = parseInt(parts[1]);
        const attributeType = parseInt(parts[2]);
        
        const colorName = COLORS_LABELS[colorId as keyof typeof COLORS_LABELS];
        
        if (colorName && seasons[season as keyof typeof seasons]) {
          const seasonData = seasons[season as keyof typeof seasons];
          
          // Map attribute types to plant parts
          switch (attributeType) {
            case 1: // Foliage
              seasonData.plant.foliage.push({ colorId, colorName });
              break;
            case 2: // Stem
              seasonData.plant.stem.push({ colorId, colorName });
              break;
            case 3: // Fruit
              seasonData.plant.fruit.push({ colorId, colorName });
              break;
            case 4: // Flower
              seasonData.plant.flower.push({ colorId, colorName });
              break;
          }
        }
      }
    });

    return seasons;
  });  // Create color style for icons (works for both single and multiple colors)
  const getIconColorStyle = (colors: Array<{ colorId: number; colorName: string }>) => {
    if (colors.length === 0) return { style: '', class: 'text-gray-400', useGradient: false };
    
    if (colors.length === 1) {
      // Single color - use RGB color directly
      const rgb = getColorRGB(colors[0].colorId);
      return { 
        style: `rgb(${rgb});`, 
        class: '',
        useGradient: false
      };
    }
    
    // Multiple colors - return gradient information for SVG implementation
    const rgbColors = colors.map(c => getColorRGB(c.colorId));
    return { 
      style: '',
      class: '',
      useGradient: true,
      gradientColors: rgbColors,
      gradientId: `gradient-${colors.map(c => c.colorId).join('-')}`
    };
  };return {
    sunlightLabels,
    soilTypeLabels,
    fullHeightTimeLabels,
    moistureLabels,
    phLabels,
    exposureLabels,
    seasonOfInterestLabels,
    rhsTypeLabels,
    colorsBySeason,
    getColorClass,
    getBaseIcon,
    graphicalPlantBySeason,
    getIconColorStyle
  };
};