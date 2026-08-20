-- Add image_url column to stores table for store avatar photos
alter table stores add column if not exists image_url text;
