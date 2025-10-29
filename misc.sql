CREATE OR REPLACE TRIGGER tr_propiedad_formulario
AFTER INSERT ON Propiedad
FOR EACH ROW
BEGIN
    pkg_tesoreria.pr_generar_formularios_propiedad(:NEW.nroRol);
END;