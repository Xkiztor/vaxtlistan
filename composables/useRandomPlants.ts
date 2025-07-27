import type { Facit } from '~/types/supabase-tables';

/**
 * Interface for random plant data with availability and images
 */
export interface RandomPlantWithStock {
  id: number;
  name: string;
  sv_name: string | null;
  plant_type: string | null;
  images: any[] | null;
  height: string | null;
  spread: string | null;
  colors: string[] | null;
  rhs_types: number[] | null;
  // Stock information
  available_count: number; // Number of nurseries with this plant in stock
  min_price: number | null;
  max_price: number | null;
  nurseries: {
    id: number;
    name: string;
    price: number;
    stock: number | null;
  }[];
}

/**
 * Basic plant interface for the database response
 */
interface PlantResponse {
  id: number;
  name: string;
  sv_name: string | null;
  plant_type: string | null;
  images: any[] | null;
  height: string | null;
  spread: string | null;
  colors: string[] | null;
  rhs_types: number[] | null;
}

/**
 * Stock response interface
 */
interface StockResponse {
  facit_id: number;
  plantskola_id: number;
  price: number;
  stock: number | null;
  plantskolor: {
    id: number;
    name: string;
    hidden: boolean;
  };
}

/**
 * Composable for fetching random plants that are available in stock and have images
 * @param limit Number of plants to fetch (default: 6)
 */
export const useRandomPlants = (limit: number = 6) => {
  const supabase = useSupabaseClient();

  /**
   * Fetch random plants that are in stock at nurseries and have images
   */
  const fetchRandomPlants = async (): Promise<RandomPlantWithStock[]> => {
    try {
      // First, get plant IDs that are in stock
      const { data: stockPlantIds, error: stockError } = await supabase
        .from('totallager')
        .select('facit_id')
        .eq('hidden', false)
        .gt('stock', 0);

      if (stockError || !stockPlantIds) {
        console.error('Error fetching stock plant IDs:', stockError);
        return [];
      }

      const availablePlantIds = stockPlantIds.map((item: any) => item.facit_id);
      
      if (availablePlantIds.length === 0) {
        return [];
      }

      // Get random plants that have images and are in the available list
      const { data: randomPlants, error: plantsError } = await supabase
        .from('facit')
        .select(`
          id,
          name,
          sv_name,
          plant_type,
          images,
          height,
          spread,
          colors,
          rhs_types
        `)
        .not('images', 'is', null) // Must have images
        .in('id', availablePlantIds)
        .order('id', { ascending: false }) // Order by id desc for some randomness
        .limit(limit * 3); // Get more than needed for better randomness

      if (plantsError) {
        console.error('Error fetching random plants:', plantsError);
        return [];
      }

      if (!randomPlants || randomPlants.length === 0) {
        return [];
      }

      // Filter plants that actually have images (not empty array)
      const plantsWithImages = (randomPlants as PlantResponse[]).filter(plant => 
        plant.images && Array.isArray(plant.images) && plant.images.length > 0
      );

      // Shuffle and take the requested amount
      const shuffledPlants = plantsWithImages
        .sort(() => Math.random() - 0.5)
        .slice(0, limit);

      // Get stock information for these plants
      const plantIds = shuffledPlants.map(p => p.id);
      
      const { data: stockData, error: stockDataError } = await supabase
        .from('totallager')
        .select(`
          facit_id,
          plantskola_id,
          price,
          stock,
          plantskolor!inner(
            id,
            name,
            hidden
          )
        `)
        .in('facit_id', plantIds)
        .eq('hidden', false)
        .eq('plantskolor.hidden', false)
        .gt('stock', 0);

      if (stockDataError) {
        console.error('Error fetching stock data:', stockDataError);
        return [];
      }

      // Combine plant data with stock information
      const result: RandomPlantWithStock[] = shuffledPlants.map(plant => {
        const stockEntries = (stockData as StockResponse[])?.filter(s => s.facit_id === plant.id) || [];
        
        const nurseries = stockEntries.map(entry => ({
          id: entry.plantskola_id,
          name: entry.plantskolor.name,
          price: entry.price,
          stock: entry.stock
        }));

        const prices = stockEntries.map(s => s.price).filter(p => p !== null && p !== undefined);
        
        return {
          id: plant.id,
          name: plant.name,
          sv_name: plant.sv_name,
          plant_type: plant.plant_type,
          images: plant.images,
          height: plant.height,
          spread: plant.spread,
          colors: plant.colors,
          rhs_types: plant.rhs_types,
          available_count: nurseries.length,
          min_price: prices.length > 0 ? Math.min(...prices) : null,
          max_price: prices.length > 0 ? Math.max(...prices) : null,
          nurseries
        };
      });

      // Only return plants that actually have stock
      return result.filter(plant => plant.available_count > 0);

    } catch (error) {
      console.error('Error in fetchRandomPlants:', error);
      return [];
    }
  };

  return {
    fetchRandomPlants
  };
};
