# Växtlistan

Växtlistan is a plant discovery platform built to help users search for plants and see which Swedish nurseries currently have them in stock. It aims to make plant shopping easier and more efficient by bridging the gap between plant buyers and sellers.

---

## Overview

The platform serves two main audiences:

- **Plant Enthusiasts / Consumers**: Easily search for specific plants and find local nurseries that carry them.
- **Nursery Owners**: Register their nursery, list their available plants, and reach a larger audience.

---

## Purpose

Växtlistan solves a real-world problem: finding specific plants in stock can be frustrating and time-consuming. We provide:

- **Searchable access** to live plant inventories
- **Visibility for nurseries**, increasing sales and customer reach
- **A centralized platform** that bridges the gap between supply and demand in the Swedish plant market

---

## Tech Stack

- **Frontend**: Nuxt 3
- **Styling**: Tailwind CSS, Nuxt UI
- **Backend/Database**: Supabase(Database, Auth)
- **State**: Pinia

---

## Features

- Full-text search for plant names
- Display of available nurseries with plant stock
- SSR-ready frontend for SEO and fast load times
- User authentication for nursery owners
- Plant listings with metadata and image uploads
- Fully responsive and mobile-friendly

---

## Data structure

This is the data structure in supabase:

### Table: "plantskolor"

| Column Name | Data Type  | Description              |
| ----------- | ---------- | ------------------------ |
| id          | Int8       | Unique identifier        |
| name        | Text       | Nursery name             |
| adress      | Text       | Address                  |
| email       | Text       | Contact email            |
| phone       | Text       | Contact phone number     |
| url         | Text       | Nursery website URL      |
| postorder   | Bool       | Supports postal orders   |
| on_site     | Bool       | Supports on-site pickup  |
| verified    | Bool       | Verification status      |
| hidden      | Bool       | hides the all the plants |
| description | Text       | Nursery description      |
| user_id     | UUID       | Linked user ID           |
| created_at  | Timestampz | Creation timestamp       |
| last_edited | Timestampz | Last edited timestamp    |

### Table: "totallager"

| Column Name                   | Data Type  | Description                                                           |
| ----------------------------- | ---------- | --------------------------------------------------------------------- |
| id                            | Int8       | Unique identifier                                                     |
| facit_id                      | Int8       | FK to facit table (linked plant reference)                            |
| plantskola_id                 | Int8       | FK to plantskolor table (linked nursery)                              |
| name_by_plantskola            | Text       | Plant name as provided by the nursery                                 |
| comment_by_plantskola         | Text       | Plant comment from the nursery                                        |
| private_comment_by_plantskola | Text       | Private comment only for the nursery                                  |
| id_by_plantskola              | Text       | Custom ID/article number assigned by nursery                          |
| pot                           | Text       | Pot size/type                                                         |
| height                        | Text       | Plant height                                                          |
| price                         | Numeric    | Price of the plant                                                    |
| hidden                        | Bool       | Visibility status (hidden or shown)                                   |
| stock                         | Int8       | Number of plants in stock, can be null if the plantskola doesn't know |
| own_columns                   | JSONB      | Custom fields added by nursery (nullable)                             |
| created_at                    | Timestampz | Creation timestamp                                                    |
| last_edited                   | Timestampz | Last edited timestamp                                                 |

// The name of the plant is never presented here. Instead it fetched from the facit table by the id. So when editing or adding a new plant the user has to chose one of the current plant names in the facit.

#### Custom Fields (own_columns)

The `own_columns` field allows nurseries to store additional custom information during import. This field uses JSONB datatype for flexible storage:

**Structure**: Key-value pairs where keys are field names chosen by the nursery and values are the corresponding data.

**Examples**:

```json
{
  "leverantör": "Plantagen AB",
  "färg": "Röd",
  "ursprung": "Sverige",
  "leveranstid": "2-3 veckor"
}
```

**Common use cases**:

- Supplier information
- Plant colors
- Origin/source
- Delivery times
- Special notes
- Internal codes
- Growing conditions

**Benefits**:

- Each nursery can define their own fields

### Table: "superadmins"

| Column Name | Data Type | Description       |
| ----------- | --------- | ----------------- |
| id          | Int8      | Unique identifier |
| user_id     | UUID      | Linked user ID    |

---

## Table: facit

### List lenght: 170 000 rows

This table contains detailed taxonomic and horticultural information for each plant. Example data and field explanations below:

| column_name           | data_type                | Example / Description                                                                                                        |
| --------------------- | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| id                    | bigint (auto-generated)  | 72388 (unique ID)                                                                                                            |
| created_at            | timestamp with time zone | '2024-05-22T12:00:00Z' (auto-set on insert)                                                                                  |
| name                  | text                     | "Pinus cembra 'Stricta'" (scientific name)                                                                                   |
| sv_name               | text                     | "Arolla pine 'Stricta'" (common/native name)                                                                                 |
| name_usage            | text                     | "Accepted", "AcceptedName" or "Synonym"                                                                                      |
| is_recommended        | boolean                  | true/false                                                                                                                   |
| is_original           | boolean                  | true/false                                                                                                                   |
| is_synonym            | boolean                  | true/false                                                                                                                   |
| synonym_to            | text                     | If synonym, the accepted name it refers to                                                                                   |
| synonym_to_id         | bigint                   | FK to facit.id - the ID of the accepted plant name                                                                           |
| has_synonyms          | text                     | List of the plants that refer to this plant. Written as seperated by a pipe/vertical line surounded by a space on each side. |
| has_synonyms_id       | text                     | Same format at has_synonyms but with the id of the plant instead.                                                            |
| taxonomy_type         | text                     | 'species', 'cultivar', etc.                                                                                                  |
| plant_type            | text                     | 'T', etc.                                                                                                                    |
| grupp                 | text                     | The grupp of the plant. Formaly as ex.(Therian-Gruppen)                                                                      |
| serie                 | text                     | same as grupp but for serie                                                                                                  |
| rhs_types             | smallint[]               | [6] (see mapping below), Sub-catergory to plant_type                                                                         |
| spread                | text                     | '2.5-4 meter'                                                                                                                |
| height                | text                     | '8-12 meter'                                                                                                                 |
| rhs_id                | bigint                   | RHS database ID                                                                                                              |
| sunlight              | smallint[]               | [1] (see mapping below)                                                                                                      |
| soil_type             | smallint[]               | [1,3] (see mapping below)                                                                                                    |
| full_height_time      | smallint[]               | [5] (see mapping below)                                                                                                      |
| moisture              | smallint[]               | [1] (see mapping below)                                                                                                      |
| ph                    | smallint[]               | [1,3] (see mapping below)                                                                                                    |
| exposure              | smallint[]               | [2,1] (see mapping below)                                                                                                    |
| season_of_interest    | smallint[]               | [1,2,3,4] (see mapping below)                                                                                                |
| colors                | text[]                   | Array of compressed strings ["8-3-1", "11-3-1"]                                                                              |
| user_submitted        | boolean                  | true/false (default: false)                                                                                                  |
| created_by            | bigint                   | User or nursery who created the entry (FK)                                                                                   |
| last_edited           | timestamp with time zone | '2024-05-22T15:30:00Z' (when last edited)                                                                                    |
| popularity_score      | numeric                  | Calculated popularity score based on search frequency and user interactions                                                  |
| images                | JSONB[]                  | Array of Google Images data objects [{url, title, sourcePage}]                                                               |
| images_reordered      | boolean                  | true/false (if images have been reordered on superadmin page)                                                                |
| images_reordered_date | timestamp with time zone | '2024-05-22T16:00:00Z' (date of reordering)                                                                                  |
| images_added_date     | timestamp with time zone | '2024-05-22T14:00:00Z' (date when images were added)                                                                         |

**Notes:**

- All fields are nullable unless otherwise specified.
- `id` is generated automatically.
- `created_at` and `last_edited` default to the current timestamp.
- Array fields use `smallint[]` for efficient storage.
- `colors` is an array of compressed strings in format "colour-season-attributeType" (e.g., "8-3-1" for Orange in Autumn with attributeType 1).
- `user_submitted` defaults to `false`.
- `images` contains Google Images search results with URL, title, and source page information.
- Image-related timestamp fields (`images_reordered_date`, `images_added_date`) are set when images are manipulated through the admin interface.

#### Field mappings (for array fields):

- sunlight: {0:"No preference",1:"Full sun",2:"Partial shade",3:"Full shade"}
- soilType: {0:"No preference",2:"Chalk",4:"Clay",1:"Loam",3:"Sand"}
- timeToFullHeight: {0:"No preference",1:"1 year",2:"1–2 years",3:"2–5 years",4:"5–10 years",5:"10–20 years",6:"20–50 years",7:"more than 50 years"}
- moisture: {0:"No preference",1:"Well-drained",2:"Poorly-drained",3:"Moist but well-drained"}
- ph: {0:"No preference",1:"Acid",2:"Alkaline",3:"Neutral"}
- exposure: {0:"No preference",1:"Sheltered",2:"Exposed"}
- seasonOfInterest: {1:"Spring",2:"Summer",3:"Autumn",4:"Winter"}
- colors: {
  'season': {1:"Spring",2:"Summer",3:"Autumn",4:"Winter"}
  'colour': {1:"Black",2:"Blue",3:"Bronze",4:"Brown",5:"Cream",6:"Green",7:"Grey",8:"Orange",9:"Pink",10:"Purple",11:"Red",12:"Silver",13:"Variegated",14:"White",15:"Yellow",16:"Gold"},
  'attributeType': # {1:"Foliage",2:"Stem",3:"Fruit",4:"Flower"}
  },
- rhs_types: {
  1: "Perennial",
  2: "Climber Wall Shrub",
  3: "Bedding",
  4: "Bulbs",
  5: "Ferns",
  6: "Shrubs",
  8: "Alpine Rockery",
  9: "Roses",
  10: "Grass Like",
  11: "Conservatory Greenhouse",
  12: "Fruit Edible",
  13: "Trees",
  17: "Bamboos",
  18: "Bogs",
  19: "Conifers"
  }

---

# Database Functions

### get_plantskola_lager_complete(plantskola_id)

A SQL function that fetches complete lager information for a specific plantskola. It joins the `totallager` table with the `facit` table to provide enriched plant data in a single query. Data from facit is prefixed with facit\_
This is used in the lager view for plantskola admin

## Plant Search Functions

- For all functions:
  The searches schould be case- and special character insensitive
  Performance is important but good results are just as important.
  Make everythinh well though out and centralized.

#### All Plants Search Functions (for PlantPicker)

Searching all plants with more basic search method for better performance.
Don't include the plants where the "synonym_to" column has any content.
Search in the "name" and "has_synonyms" columns
Return id, name, sv_name, plant_type, has_synonyms, has_synonyms_id, user_submitted and created_by

#### Fuzzy and strict name match (for import) (search-plants.sql)

First matches the name quickly using regular case and special character insenstive search.
Then if not found, matches the name using fuzzy simularity search to allow for typos.
Use tg_trgm and GIN indexes for fast perfomance.
This is to display the "menade du?" options.
Here you can ignore the plants where "synonym_to" has any content.
Search in the "name" and "has_synonyms" columns
Return id, name, sv_name, plant_type, has_synonyms, has_synonyms_id, user_submitted and created_by

#### Available Plants Search Functions (for search page and inline search)

**Key Features of Available Plants Functions:**

JOIN with totallager table to only return plants in stock
Returns additional fields: `available_count`, `plantskolor_count`, and `prices` (array of all prices)
Includes `similarity_score` field for fuzzy search results
Optional `include_hidden` parameter to filter hidden plants
Results ordered by relevance and availability
Defaults to fuzzy search for better typo tolerance and user experience. Fuzzy search can be used here as the dataset is a lot smaller as only avilable plants are displayed.
Aggregates all prices for each plant to show the cheapest available price
Return all the relevant columns.

**Price Aggregation:**
Each search result includes a `prices` array of objects containing all prices for that plant across different nurseries. This allows the UI to display the cheapest available price to users.

#### Sanitize plant name

Centralized sanitation. Use this in all functions to avoid repetition.
