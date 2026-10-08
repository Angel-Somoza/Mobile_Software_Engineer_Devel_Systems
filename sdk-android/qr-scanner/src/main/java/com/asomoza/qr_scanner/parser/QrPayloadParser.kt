package com.asomoza.qr_scanner.parser

internal object QrPayloadParser {

    private var DATA = "product:"

    private val ID_FORMAT = Regex("[1-9][0-9]*")

    fun parse(raw: String?): QrParseResult {

        if(raw == null || !raw.startsWith(DATA)){
            return QrParseResult.invalid(QrParserReason.BAD)
        }
        val id = raw.substring(DATA.length)
        if(!ID_FORMAT.matches(id)){
            return QrParseResult.invalid(QrParserReason.BAD)
        }
        val idRange = id.toIntOrNull() ?: return QrParseResult.invalid(QrParserReason.OUT_OF_RANGE)

        return QrParseResult.valid(idRange)
    }
}