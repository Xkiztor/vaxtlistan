Hi AI! Use this file as instructions:

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
- **Hosting**: Netlify
- **State**: Pinia

---

## Rules - !!IMPORTANT!!

This is for a production website!! (VERY IMPORTANT!!) Write everything proffessianaly.
Always use Nuxt UI components (only the ones that exist). They start with U and then the normal name of the element. Use https://ui.nuxt.com/
Write comments for everything. Write readable code.
Use supabase like: "const supabase = useSupabaseClient();"
Use Typescript and define types
You don't need to import to vue files as everything is auto-imported (some things still needs to be imported)
Use Nuxt 3 conventions (definePageMeta, useAsyncData, etc.)
Use arrow functions.

---

## Design

Always use the variables for color. Never any own colours. The variables are found in main.css or default tailwind classes.
The design should be modern and clean. A bit rounded. No exessive drop shadows. It should apeal for the averarage adult.

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

### Table: "facit"

#### name - type:

id - Int8
name - Text
sv_name - Text

type - Text
edible - Bool
zone - Int8
max_height - Int8
max_width - Int8
created_at - Timestampz
last_edited - Timestampz

### Table: "plantskolor"

#### name - type:

id - Int8
name - Text
adress - Text
email - Text
phone - Text
verified - Bool
description - Text
user_id - UUID
created_at - Timestampz
last_edited - Timestampz

### Table: "totallager"

#### name - type:

id - Int8
facit_id - Int8 (FK facit, linked)
plantskola_id - Int8 (FK plantskolor, linked)
name_by_plantskola - Text
description_by_plantskola - Text
pot - Text
height - Text
price - Numeric
hidden - Bool
stock - Int8
created_at - Timestampz
last_edited - Timestampz

### Table: "superadmins"

#### name - type:

id - Int8
user_id - UUID
