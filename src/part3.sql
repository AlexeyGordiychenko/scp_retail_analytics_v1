-- Create Administrator role with full access
CREATE ROLE "Administrator" SUPERUSER LOGIN;

-- Create Visitor role
CREATE ROLE "Visitor" LOGIN;

-- Allow Visitor to select from all tables
GRANT pg_read_all_data TO "Visitor";