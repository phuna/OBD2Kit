/*
 *  FLLogging.h
 *  OBD2Kit
 *
 *  Copyright (c) 2009-2011 FuzzyLuke Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#define VERBOSE_DEBUG			1
//#undef VERBOSE_DEBUG

#define VERBOSE_INFO			1
//#undef VERBOSE_INFO

#define CONCAT(s1, s2) s1 s2

/*
 Trace Macro
 */
#ifdef VERBOSE_DEBUG
#	define FLTRACE(...) NSLog(__VA_ARGS__);
#elif VERBOSE_INFO
#	define FLTRACE(...) NSLog(__VA_ARGS__);
#else
#	define FLTRACE
#endif


/*
 Function Entry Macro 
 */
#ifdef VERBOSE_DEBUG
#	define FLTRACE_ENTRY NSLog(@"[ENTRY] %s (%d)", __PRETTY_FUNCTION__, __LINE__);
#else
#	define FLTRACE_ENTRY
#endif


/*
 Function Exit Macro
 */
#ifdef VERBOSE_DEBUG
#	define FLTRACE_EXIT NSLog(@"[EXIT] %s (%d)", __PRETTY_FUNCTION__, __LINE__);
#else
#	define FLTRACE_EXIT
#endif


/*
 Informational Message
 */
#ifdef VERBOSE_INFO
#	define FLINFO(msg) FLTRACE(@CONCAT("[INFO] %s (%d): ", msg), __PRETTY_FUNCTION__, __LINE__)
#else
#	define FLINFO(msg)
#endif


/*
 Debug Message
 */
#ifdef VERBOSE_DEBUG
#	define FLDEBUG(fmt, ...) FLTRACE(@CONCAT("[DEBUG] %s (%d): ", fmt), __PRETTY_FUNCTION__, __LINE__, __VA_ARGS__)
#else
#	define FLDEBUG(fmt, ...)
#endif


/*
 Error Message
 */
#define FLERROR(fmt, ...) FLTRACE(@CONCAT("[ERROR] %s (%d): ", fmt), __PRETTY_FUNCTION__, __LINE__, __VA_ARGS__)


/*
 NSError trace
 */
#define FLNSERROR(err) if(err) {						\
	FLTRACE(@"[NSError] %s (%ld): (%ld:%@) Reason: %@",	\
		__PRETTY_FUNCTION__,							\
		(long)__LINE__,									\
		(long)err.code,									\
		err.domain,										\
		err.localizedDescription)						\
}


/*
 Exception Message
 */
#define FLEXCEPTION(e) if(e) {							\
	FLTRACE(@"[EXCEPTION] %s (%d): %@ (%@ || %@)",		\
		__PRETTY_FUNCTION__,							\
		__LINE__,										\
		e.name,											\
		e.reason,										\
		e.userInfo)										\
}

static char *MyLogString(char *str)
{
    static char     buf[2048];
    char            *ptr = buf;
    int             i;
	
    *ptr = '\0';
	
    while (*str)
    {
        if (isprint(*str))
        {
            *ptr++ = *str++;
        }
        else {
            switch(*str)
            {
				case ' ':
					*ptr++ = *str;
					break;
					
				case 27:
					*ptr++ = '\\';
					*ptr++ = 'e';
					break;
					
				case '\t':
					*ptr++ = '\\';
					*ptr++ = 't';
					break;
					
				case '\n':
					*ptr++ = '\\';
					*ptr++ = 'n';
					break;
					
				case '\r':
					*ptr++ = '\\';
					*ptr++ = 'r';
					break;
					
				default:
					i = *str;
					(void)sprintf(ptr, "\\%03o", i);
					ptr += 4;
					break;
            }
			
            str++;
        }
        *ptr = '\0';
    }
    return buf;
}
