-- Encabezado del paquete
CREATE OR REPLACE PACKAGE pkg_tesoreria IS
    PROCEDURE pr_registrar_error(
        p_rutina VARCHAR2,
        p_msjError VARCHAR2
    );
    PROCEDURE pr_mostrar_propiedades_exencion_prox_anio(
        p_porcentajeValor NUMBER
    );
    FUNCTION fn_valorizacion_propiedad(
        p_nroRol PROPIEDAD.NROROL%TYPE
    ) RETURN NUMBER;
    FUNCTION fn_incrementar_valorizado_propiedad(
        p_nroRol PROPIEDAD.NROROL%TYPE,
        p_porcentaje NUMBER
    ) RETURN NUMBER;
    FUNCTION fn_calcular_contribucion_propiedad (
        p_nrorol IN PROPIEDAD.NROROL%TYPE
    ) RETURN NUMBER;
END pkg_tesoreria;
/
-- Cuerpo del paquete
CREATE OR REPLACE PACKAGE BODY pkg_tesoreria IS
    PROCEDURE pr_registrar_error(
        p_rutina VARCHAR2,
        p_msjError VARCHAR2
    ) IS
        v_correlativo NUMBER;
    BEGIN
        SELECT seq_error.NEXTVAL INTO v_correlativo FROM dual;
        
        INSERT INTO error_calc_avaluos (
            correlativo,
            rutina_error,
            mensaje_error
        ) VALUES (
            v_correlativo,
            p_rutina,
            p_msjError
        );
    END;
    
    PROCEDURE pr_mostrar_propiedades_exencion_prox_anio(
        p_porcentajeValor NUMBER
    ) IS
        v_nroRol    Propiedad.nroRol%TYPE;
        v_calle     Propiedad.calle%TYPE;
        v_numero    Propiedad.numero%TYPE;
        v_tipo      Propiedad.tipo%TYPE;
        
        v_valor         NUMBER;
        v_valorAjustado NUMBER;
        
        CURSOR c_propiedades IS
            SELECT P.nroRol, P.calle, P.numero, P.tipo
            FROM Propiedad P
            WHERE EXTRACT(YEAR FROM P.fecha_ingreso) + 20 = EXTRACT(YEAR FROM SYSDATE) + 1;
    BEGIN
        OPEN c_propiedades;
        LOOP
            FETCH c_propiedades INTO v_nroRol, v_calle, v_numero, v_tipo;
            EXIT WHEN c_propiedades%NOTFOUND;
            v_valor := fn_valorizacion_propiedad(v_nroRol);
            v_valorAjustado := ROUND(v_valor * p_porcentajeValor, 0);
            DBMS_OUTPUT.PUT_LINE(
                '[Dirección: ' || v_calle || ' ' || v_numero
                || '] [Tipo: ' || v_tipo
                || '] [Valor: $' || v_valor
                || '] [Valor ajustado al ' || ROUND(p_porcentajeValor * 100, 0) || '%: $' || v_valorAjustado || ']');
        END LOOP;
    END;
    
    FUNCTION fn_valorizacion_propiedad(
        p_nroRol PROPIEDAD.NROROL%TYPE
    ) RETURN NUMBER IS
        v_valorUF VALOR_UF.VALOR_EN_PESOS%TYPE;
        v_superficie NUMBER;
        v_valorizado NUMBER;
    BEGIN
        SELECT superficie INTO v_superficie
        FROM Propiedad WHERE nrorol = p_nroRol;
        
        SELECT valor_en_pesos INTO v_valorUF
        FROM Valor_UF WHERE fecha = (SELECT MAX(fecha) FROM valor_uf);
        
        v_valorizado := v_superficie * v_valorUF;
        RETURN v_valorizado;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pr_registrar_error(
                'fn_valorizacion_propiedad',
                'Propiedad con nroRol = ' || p_nroRol || ' no encontrada.');
            RAISE;
    END;
    
    FUNCTION fn_incrementar_valorizado_propiedad(
        p_nroRol PROPIEDAD.NROROL%TYPE,
        p_porcentaje NUMBER
    ) RETURN NUMBER IS
        v_valorizado NUMBER;
        v_valorizado_incrementado NUMBER;
    BEGIN
        v_valorizado := fn_valorizacion_propiedad(p_nroRol);
        v_valorizado_incrementado := v_valorizado * (1 + p_porcentaje / 100);
        RETURN v_valorizado_incrementado;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pr_registrar_error(
                'fn_incrementar_valorizado_propiedad',
                'Propiedad con nroRol = ' || p_nroRol || 'no encontrada.');
            RAISE;
    END;
    
    FUNCTION fn_calcular_contribucion_propiedad (
        p_nrorol IN PROPIEDAD.NROROL%TYPE
    ) RETURN NUMBER IS
        v_valorizado NUMBER;
        v_contribucion NUMBER;
    BEGIN
        v_valorizado := fn_valorizacion_propiedad(p_nrorol);
        v_contribucion := v_valorizado * 0.16;
        RETURN v_contribucion;
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pr_registrar_error(
                'fn_calcular_contribucion_propiedad',
                'Propiedad con nroRol = ' || p_nroRol || 'no encontrada.');
            RAISE;
    END;
END pkg_tesoreria;
