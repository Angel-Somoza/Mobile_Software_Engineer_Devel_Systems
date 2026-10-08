package com.asomoza.qr_scanner

import com.asomoza.qr_scanner.parser.QrParseResult
import com.asomoza.qr_scanner.parser.QrParserReason
import com.asomoza.qr_scanner.parser.QrPayloadParser
import org.junit.Test
import org.junit.Assert.*


class QrPayloadParserTest {

    private fun assertValid(expectedId: Int, raw: String?) =
        assertEquals(QrParseResult.valid(expectedId), QrPayloadParser.parse(raw))

    private fun assertInvalid(raw: String?, reason: QrParserReason = QrParserReason.BAD) =
        assertEquals(QrParseResult.invalid(reason), QrPayloadParser.parse(raw))

    @Test fun `ids de prueba del son validos`() {
        assertValid(1, "product:1")
        assertValid(2, "product:2")
        assertValid(3, "product:3")
        assertValid(999999, "product:999999")
    }

    @Test fun `cero, negativo y ceros iniciales son invalidos`() {
        listOf("product:0", "product:-1", "product:01", "product:+1")
            .forEach { assertInvalid(it) }
    }

    @Test fun `namedata incorrecto o id no numerico es invalido`() {
        listOf("PRODUCT:1", "Product:1", "product:abc", "hola", "product1", "")
            .forEach { assertInvalid(it) }
        assertInvalid(null)
    }

    @Test fun `sin id o con decimal es invalido`() {
        assertInvalid("product:")
        assertInvalid("product:1.5")
    }

    @Test fun `los espacios y los saltos de linea son invalidos`() {
        listOf("product: 1", "product:1 ", " product:1", "product:1\n", "product:1\r\n")
            .forEach { assertInvalid(it) }
    }

    @Test fun `no ascii son invalidos`() {
        assertInvalid("product:\u0661")
        assertInvalid("product:１")
    }

    @Test fun `Limite del rango Int`() {
        assertValid(Int.MAX_VALUE, "product:2147483647")
        assertInvalid("product:2147483648", QrParserReason.OUT_OF_RANGE)
        assertInvalid("product:99999999999999999999", QrParserReason.OUT_OF_RANGE)
    }
}