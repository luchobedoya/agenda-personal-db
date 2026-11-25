-- ============================================================================
-- 1. CREACIÓN DE TABLAS (DDL)
-- ============================================================================

-- Tabla de categorías (se crea primero porque contactos depende de ella)
CREATE TABLE IF NOT EXISTS categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de contactos
CREATE TABLE IF NOT EXISTS contactos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(20),
    email VARCHAR(100),
    categoria_id INT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_contactos_categoria
        FOREIGN KEY (categoria_id)
        REFERENCES categorias(id)
        ON DELETE SET NULL
);

-- Índice en la llave foránea para acelerar búsquedas por categoría
CREATE INDEX IF NOT EXISTS idx_contactos_categoria_id ON contactos(categoria_id);


-- ============================================================================
-- 2. INSERCIÓN DE DATOS INICIALES / SEED (DML)
-- ============================================================================

-- Insertar categorías base (evita error si ya existen al re-ejecutar el script)
INSERT INTO categorias (nombre) VALUES
    ('Familia'),
    ('Trabajo'),
    ('Amigos'),
    ('Servicios')
ON CONFLICT (nombre) DO NOTHING;

-- Insertar contactos de prueba asociando la categoría por su nombre
INSERT INTO contactos (nombre, telefono, email, categoria_id) VALUES
    (
        'Laura Martínez',
        '+57 300 456 7890',
        'laura.martinez@email.com',
        (SELECT id FROM categorias WHERE nombre = 'Familia')
    ),
    (
        'Andrés Restrepo',
        '+57 311 234 5678',
        'andres.restrepo@empresa.com',
        (SELECT id FROM categorias WHERE nombre = 'Trabajo')
    ),
    (
        'Camila Gómez',
        '+57 320 987 6543',
        'camila.gomez@email.com',
        (SELECT id FROM categorias WHERE nombre = 'Amigos')
    ),
    (
        'Soporte Internet Hogar',
        '604 444 1234',
        'soporte@proveedor.com',
        (SELECT id FROM categorias WHERE nombre = 'Servicios')
    );