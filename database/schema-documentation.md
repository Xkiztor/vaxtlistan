# Database Schema Documentation

## Table: facit

The `facit` table contains the authoritative plant information and serves as the main reference for all plant data in the system.

### Columns

| Column | Type | Description |
|--------|------|-------------|
| `id` | `bigint` | Primary key. Auto-generated unique identifier for the plant |
| `created_at` | `timestamptz` | When the record was created |
| `name` | `text` | Scientific name (e.g. "Pinus cembra 'Stricta'") |
| `sv_name` | `text` | Swedish/common name (e.g. "Arolla pine 'Stricta'") |
| `is_recommended` | `boolean` | Whether this is a recommended name |
| `is_original` | `boolean` | Whether this is the original name |
| `is_synonym` | `boolean` | Whether this is a synonym |
| `synonym_to` | `text` | If synonym, the accepted name it refers to |
| `synonym_to_id` | `bigint` | FK to facit.id - the ID of the accepted plant name |
| `has_synonyms` | `text` | Pipe-separated plant names that refer to this plant |
| `has_synonyms_id` | `text` | Pipe-separated plant IDs that refer to this plant |
| `taxonomy_type` | `text` | Type of taxonomy (e.g. "species", "cultivar") |
| `plant_type` | `text` | Plant type/category (e.g. "T" for trees) |
| `grupp` | `text` | The group of the plant (e.g. "Therian-Gruppen") |
| `serie` | `text` | The series of the plant |
| `spread` | `text` | Typical spread (e.g. "2.5-4 meter") |
| `height` | `text` | Typical height (e.g. "8-12 meter") |
| `rhs_id` | `bigint` | RHS database ID |
| `sunlight` | `smallint[]` | Array of sunlight preferences |
| `soil_type` | `smallint[]` | Array of soil type preferences |
| `full_height_time` | `smallint[]` | Array of time to full height values |
| `moisture` | `smallint[]` | Array of moisture preferences |
| `ph` | `smallint[]` | Array of soil pH preferences |
| `exposure` | `smallint[]` | Array of exposure preferences |
| `season_of_interest` | `smallint[]` | Array of seasons of interest |
| `colors` | `text[]` | Array of color attributes in compressed format |
| `rhs_types` | `smallint[]` | Array of RHS plant types (sub-category of plant_type) |
| `images` | `jsonb` | Array of Google Photos search results with image data |
| `images_reordered` | `bool` | If the images has been reordered
| `images_reordered_date` | `timestamptz` | Timestamp of the last reorder |
| `images_added_date` | `timestamptz` | Timestamp when images were first added |
| `user_submitted` | `boolean` | Whether the entry was user-submitted |
| `created_by` | `bigint` | User or nursery who created the entry |
| `last_edited` | `timestamptz` | When last edited |

### Google Photos Column Structure

The `images` column stores an array of image objects fetched from Google Images when a user navigates to a specific plant's page. This data is only fetched if it doesn't already exist for the plant.

#### Data Structure

```json
[
  {
    "url": "https://example.com/image1.jpg",
    "title": "Pinus cembra in natural habitat",
    "sourcePage": "https://source-website.com/page"
  },
  {
    "url": "https://example.com/image2.jpg", 
    "title": "Close-up of Pinus cembra needles",
    "sourcePage": "https://another-source.com/article"
  }
]
```

#### Field Descriptions

- **`url`** (`string`): Direct URL to the image file
- **`title`** (`string`): Descriptive title or alt text for the image
- **`sourcePage`** (`string`): URL of the webpage where the image was found

#### Usage

- Images are automatically fetched from Google when a user visits a plant's detail page
- Only fetched if the `images` field is `null` or empty
- Provides visual references to help users identify plants
- Enhances user experience with rich media content

#### Example SQL

```sql
-- Check if images data exists
SELECT images FROM facit WHERE id = 123;

-- Update images with new data
UPDATE facit 
SET images = '[
  {
    "url": "https://example.com/image.jpg",
    "title": "Plant image",
    "sourcePage": "https://source.com"
  }
]'::jsonb
WHERE id = 123;
```

## Database Indexes

The following indexes should be created to optimize queries involving the `images` column:

```sql
-- GIN index for efficient JSONB queries on images
CREATE INDEX IF NOT EXISTS idx_facit_images_gin 
ON facit USING gin (images);

-- Partial index for plants without images (for batch processing)
CREATE INDEX IF NOT EXISTS idx_facit_missing_images 
ON facit (id) 
WHERE images IS NULL;
```
