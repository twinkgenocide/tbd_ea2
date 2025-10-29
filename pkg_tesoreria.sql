-- Encabezado del paquete
CREATE OR REPLACE PACKAGE pkg_tesoreria IS
    PROCEDURE pr_registrar_error(
        p_rutina VARCHAR2,
        p_msjError VARCHAR2,
        p_correlativo IN OUT NUMBER
    );
    PROCEDURE pr_generar_formularios;
    PROCEDURE pr_generar_formularios_propiedad(
        p_nroRol PROPIEDAD.NROROL%TYPE
    );
    PROCEDURE pr_mostrar_propiedades_exencion_prox_anio(
        p_porcentajeValor NUMBER
    );
    FUNCTION fn_valorizacion_propiedad(
        p_nroRol PROPIEDAD.NROROL%TYPE,
        p_correlativo IN OUT NUMBER
    ) RETURN NUMBER;
    FUNCTION fn_incrementar_valorizado_propiedad(
        p_nroRol PROPIEDAD.NROROL%TYPE,
        p_porcentaje NUMBER,
        p_correlativo IN OUT NUMBER
    ) RETURN NUMBER;
    FUNCTION fn_calcular_contribucion_propiedad (
        p_nrorol IN PROPIEDAD.NROROL%TYPE,
        p_correlativo IN OUT NUMBER
    ) RETURN NUMBER;
END pkg_tesoreria;
/
-- Cuerpo del paquete
CREATE OR REPLACE PACKAGE BODY pkg_tesoreria IS
    PROCEDURE pr_registrar_error(
        p_rutina VARCHAR2,
        p_msjError VARCHAR2,
        p_correlativo IN OUT NUMBER
    ) IS
    BEGIN
        IF p_correlativo IS NULL THEN
            SELECT seq_error.NEXTVAL INTO p_correlativo FROM dual;
        END IF;
        
        INSERT INTO error_calc_avaluos (
            correlativo,
            rutina_error,
            mensaje_error
        ) VALUES (
            p_correlativo,
            p_rutina,
            p_msjError
        );
    END;
    
    PROCEDURE pr_generar_formularios IS
    BEGIN
        -- procedimiento de utilidad; no se pidió, pero nos sirve
        DELETE FROM Formulario;
        FOR rec IN (SELECT nroRol FROM Propiedad) LOOP
            pr_generar_formularios_propiedad(rec.nroRol);
        END LOOP;
    END;
    
    PROCEDURE pr_generar_formularios_propiedad( 
        p_nroRol    Propiedad.nroRol%TYPE
    ) IS
        v_correlativo NUMBER;
        
        v_calle         Propiedad.calle%TYPE;
        v_numero        Propiedad.numero%TYPE;
        v_fechaIngreso  Propiedad.fecha_ingreso%TYPE;
        v_estado        Propiedad.estado%TYPE;
        v_comuna        Comuna.nomComna%TYPE;
        v_ciudad        Ciudad.nomCiudad%TYPE;
        v_provincia     Provincia.nomProvincia%TYPE;
        v_region        Region.nomRegion%TYPE;
        
        v_valorizado    NUMBER;
        v_val_exento    NUMBER;
        v_val_afecto    NUMBER;
        v_termino_ex    NUMBER;
        v_periodo       Periodo%ROWTYPE;
    BEGIN
        v_correlativo := NULL;
        SELECT
            PR.calle, PR.numero, PR.fecha_ingreso, PR.estado,
            CO.nomComna, CI.nomCiudad, PV.nomProvincia, RG.nomRegion
        INTO
            v_calle, v_numero, v_fechaIngreso, v_estado,
            v_comuna, v_ciudad, v_provincia, v_region
        FROM Propiedad PR
            JOIN Comuna CO ON PR.codComuna = CO.codComuna
            JOIN Ciudad CI ON CO.codCiudad = CI.codCiudad
            JOIN Provincia PV ON CI.codProvincia = PV.codProvincia
            JOIN Region RG ON PV.codRegion = RG.codRegion
        WHERE PR.nroRol = p_nroRol;
        
        v_valorizado := fn_valorizacion_propiedad(p_nroRol, v_correlativo);
        v_val_afecto := fn_calcular_contribucion_propiedad(p_nroRol, v_correlativo);
        v_val_exento := v_valorizado - v_val_afecto;
            
        FOR i IN TO_NUMBER(TO_CHAR(SYSDATE, 'Q'))..4 LOOP
            SELECT * INTO v_periodo FROM Periodo
            WHERE fechaCompleta = (
                SELECT MAX(fechaCompleta)
                FROM Periodo
                WHERE annoCalendario = EXTRACT(YEAR FROM SYSDATE)
                    AND nroCuatrimestre = i
            );
            
            INSERT INTO Formulario(
                nroRol, periodo, nroCuota,
                region, provincia, ciudad, comuna,
                calle, numero, avaluo_exento,
                avaluo_afecto, avaluo_total,
                anno_termino_exencion, estado
            ) VALUES (
                p_nroRol, TO_NUMBER(TO_CHAR(v_periodo.fechaCompleta, 'YYYYMMDD')), i,
                v_region, v_provincia, v_ciudad, v_comuna, v_calle, v_numero,
                v_val_exento, v_val_afecto, v_valorizado,
                EXTRACT(YEAR FROM v_fechaIngreso) + 20, v_estado
            );
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            pr_registrar_error('pr_generar_formularios_prop...', SQLERRM, v_correlativo);
            DBMS_OUTPUT.PUT_LINE('pr_general_formularios_propiedad - prop. ' || p_nroRol || ' no encontrada.');
    END;
    
    PROCEDURE pr_mostrar_propiedades_exencion_prox_anio(
        p_porcentajeValor NUMBER
    ) IS
        v_correlativo NUMBER;
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
        v_correlativo := NULL;
        OPEN c_propiedades;
        LOOP
            FETCH c_propiedades INTO v_nroRol, v_calle, v_numero, v_tipo;
            EXIT WHEN c_propiedades%NOTFOUND;
            BEGIN
                v_valor := fn_valorizacion_propiedad(v_nroRol, v_correlativo);
                v_valorAjustado := ROUND(v_valor * p_porcentajeValor, 0);
                DBMS_OUTPUT.PUT_LINE(
                    '[Dirección: ' || v_calle || ' ' || v_numero
                    || '] [Tipo: ' || v_tipo
                    || '] [Valor: $' || v_valor
                    || '] [Valor ajustado al ' || ROUND(p_porcentajeValor * 100, 0) || '%: $' || v_valorAjustado || ']');
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pr_registrar_error('pr_mostrar_propiedades_exencion_prox_anio', SQLERRM, v_correlativo);
                    CONTINUE;
            END;
        END LOOP;
    END;
    
    FUNCTION fn_valorizacion_propiedad(
        p_nroRol PROPIEDAD.NROROL%TYPE,
        p_correlativo IN OUT NUMBER
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
            pr_registrar_error('fn_valorizacion_propiedad', SQLERRM, p_correlativo);
            RAISE;
    END;
    
    FUNCTION fn_incrementar_valorizado_propiedad(
        p_nroRol PROPIEDAD.NROROL%TYPE,
        p_porcentaje NUMBER,
        p_correlativo IN OUT NUMBER
    ) RETURN NUMBER IS
        v_valorizado NUMBER;
        v_valorizado_incrementado NUMBER;
    BEGIN
        v_valorizado := fn_valorizacion_propiedad(p_nroRol, p_correlativo);
        v_valorizado_incrementado := v_valorizado * (1 + p_porcentaje / 100);
        RETURN v_valorizado_incrementado;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pr_registrar_error('fn_incrementar_valorizado_propiedad', SQLERRM, p_correlativo);
            RAISE;
    END;
    
    FUNCTION fn_calcular_contribucion_propiedad (
        p_nrorol IN PROPIEDAD.NROROL%TYPE,
        p_correlativo IN OUT NUMBER
    ) RETURN NUMBER IS
        v_valorizado NUMBER;
        v_contribucion NUMBER;
    BEGIN
        v_valorizado := fn_valorizacion_propiedad(p_nrorol, p_correlativo);
        v_contribucion := v_valorizado * 0.16;
        RETURN v_contribucion;
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pr_registrar_error('fn_calcular_contribucion_propiedad', SQLERRM, p_correlativo);
            RAISE;
    END;
END pkg_tesoreria;
/
COMMIT;