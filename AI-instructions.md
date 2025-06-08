Hi AI! Use this file as instructions:

# Rules - !!IMPORTANT!!

When you are in Agent mode, do the edits for me, don't tell me what to do. (Sometimes editing is not fitting in the situation or there are multiple alternatives, then don't edit.)
Never run commands in terminal to build or run developer server.
When i have edited someting in beatween promts, don't revert those changes.
This is for a production website!! (VERY IMPORTANT!!) Write everything proffessianaly. The UX should be very good.
Always use Nuxt UI components (only the up to date ones that exist). They start with U and then the normal name of the element. Use https://ui.nuxt.com/
Write comments for everything. Write readable code.
Use supabase like: "const supabase = useSupabaseClient();"
Use Typescript and define types
You don't need to import to vue files as everything is auto-imported (some things still needs to be imported, like types, nothing else)
Use Nuxt 3 conventions (definePageMeta, useAsyncData, etc.)
Always use "useAsyncData" (very important for SSR and load times)
Use arrow functions.
Make everything SEO compatible. Use semantic html.
Make the site fast and responsive and utilize server side rendering. Performance is very important.
Always handle errors.

---

## Design

Always use the variables for color. Never any own colours. The variables are found in main.css or default tailwind classes.
The design should be modern and clean. A bit rounded. No exessive drop shadows. It should apeal for the averarage adult.

---

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

| Column Name | Data Type  | Description           |
| ----------- | ---------- | --------------------- |
| id          | Int8       | Unique identifier     |
| name        | Text       | Nursery name          |
| adress      | Text       | Address               |
| email       | Text       | Contact email         |
| phone       | Text       | Contact phone number  |
| verified    | Bool       | Verification status   |
| description | Text       | Nursery description   |
| user_id     | UUID       | Linked user ID        |
| created_at  | Timestampz | Creation timestamp    |
| last_edited | Timestampz | Last edited timestamp |

### Table: "totallager"

| Column Name               | Data Type  | Description                                |
| ------------------------- | ---------- | ------------------------------------------ |
| id                        | Int8       | Unique identifier                          |
| facit_id                  | Int8       | FK to facit table (linked plant reference) |
| plantskola_id             | Int8       | FK to plantskolor table (linked nursery)   |
| name_by_plantskola        | Text       | Plant name as provided by the nursery      |
| description_by_plantskola | Text       | Plant description from the nursery         |
| pot                       | Text       | Pot size/type                              |
| height                    | Text       | Plant height                               |
| price                     | Numeric    | Price of the plant                         |
| hidden                    | Bool       | Visibility status (hidden or shown)        |
| stock                     | Int8       | Number of plants in stock                  |
| created_at                | Timestampz | Creation timestamp                         |
| last_edited               | Timestampz | Last edited timestamp                      |

// The name of the plant is never presented here. Instead it fetched from the facit table by the id. So when editing or adding a new plant the user has to chose one of the current plant names in the facit.

### Table: "superadmins"

| Column Name | Data Type | Description       |
| ----------- | --------- | ----------------- |
| id          | Int8      | Unique identifier |
| user_id     | UUID      | Linked user ID    |

---

## Table: facit

### List lenght: 170 000 rows

This table contains detailed taxonomic and horticultural information for each plant. Example data and field explanations below:

| column_name        | data_type                | Example / Description                           |
| ------------------ | ------------------------ | ----------------------------------------------- |
| id                 | bigint (auto-generated)  | 72388 (unique ID)                               |
| created_at         | timestamp with time zone | '2024-05-22T12:00:00Z' (auto-set on insert)     |
| name               | text                     | "Pinus cembra 'Stricta'" (scientific name)      |
| sv_name            | text                     | "Arolla pine 'Stricta'" (common/native name)    |
| is_recommended     | boolean                  | true/false                                      |
| is_original        | boolean                  | true/false                                      |
| is_synonym         | boolean                  | true/false                                      |
| synonym_to         | text                     | If synonym, the accepted name it refers to      |
| taxonomy_type      | text                     | 'species', 'cultivar', etc.                     |
| plant_type         | text                     | 'T', etc.                                       |
| rhs_hardiness      | bigint                   | 9 (see mapping below)                           |
| spread             | text                     | '2.5-4 meter'                                   |
| height             | text                     | '8-12 meter'                                    |
| rhs_id             | bigint                   | RHS database ID                                 |
| sunlight           | smallint[]               | [1] (see mapping below)                         |
| soil_type          | smallint[]               | [1,3] (see mapping below)                       |
| full_height_time   | smallint[]               | [5] (see mapping below)                         |
| moisture           | smallint[]               | [1] (see mapping below)                         |
| ph                 | smallint[]               | [1,3] (see mapping below)                       |
| exposure           | smallint[]               | [2,1] (see mapping below)                       |
| season_of_interest | smallint[]               | [1,2,3,4] (see mapping below)                   |
| colors             | text[]                   | Array of compressed strings ["8-3-1", "11-3-1"] |
| rhs_types          | smallint[]               | [6] (see mapping below)                         |
| user_submitted     | boolean                  | true/false (default: false)                     |
| created_by         | bigint                   | User or nursery who created the entry (FK)      |
| last_edited        | timestamp with time zone | '2024-05-22T12:00:00Z' (auto-set on update)     |

**Notes:**

- All fields are nullable unless otherwise specified.
- `id` is generated automatically.
- `created_at` and `last_edited` default to the current timestamp.
- Array fields use `smallint[]` for efficient storage.
- `colors` is an array of compressed strings in format "colour-season-attributeType" (e.g., "8-3-1" for Orange in Autumn with attributeType 1).
- `user_submitted` defaults to `false`.

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
