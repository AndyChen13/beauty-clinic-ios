-- Create store-images storage bucket for store avatars
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'store-images',
    'store-images',
    true,
    5242880, -- 5MB limit
    array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Enable RLS on objects
alter table storage.objects enable row level security;

-- Allow authenticated users to upload store images
CREATE POLICY "Allow authenticated uploads to store-images"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'store-images'
    );

-- Allow anyone to read store images (public bucket)
CREATE POLICY "Allow public read on store-images"
    ON storage.objects
    FOR SELECT
    TO anon, authenticated
    USING (
        bucket_id = 'store-images'
    );

-- Allow authenticated users to update their own uploads
CREATE POLICY "Allow authenticated update on store-images"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'store-images'
    )
    WITH CHECK (
        bucket_id = 'store-images'
    );

-- Allow authenticated users to delete from store-images
CREATE POLICY "Allow authenticated delete on store-images"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'store-images'
    );
